from __future__ import annotations

import os
import re
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from time import perf_counter
from typing import Literal, NotRequired, Sequence, TypedDict

import cv2
import numpy as np

# PaddlePaddle 3.3.x has a Linux CPU oneDNN/PIR regression that breaks OCR inference.
# Keep the safer plain Paddle runtime unless a caller explicitly opts back in.
os.environ.setdefault("PADDLE_PDX_ENABLE_MKLDNN_BYDEFAULT", "0")

from paddleocr import PaddleOCR
from paddlex.inference.pipelines.ocr.result import OCRResult
from paddlex.model import create_model


REPO_ROOT = Path(__file__).resolve().parents[2]
FAST_RECOGNIZER_MODEL = "PP-OCRv5_server_rec"
WRITE_DEBUG_IMAGES = False
MIN_CONFIDENT_SCORE = 0.82
FAST_RECOGNIZER_MIN_SCORE = 0.9
FALLBACK_LANGUAGES = ("japan", "korean", "ch")


debug_path = REPO_ROOT / "debug"
debug_path.mkdir(parents=True, exist_ok=True)

_TEXT_RECOGNIZER_CACHE = globals().get("_TEXT_RECOGNIZER_CACHE", {})
_OCR_CACHE = globals().get("_OCR_CACHE", {})


@dataclass(frozen=True)
class PokemonCardInformation:
    full_title: str | None
    trainer_name: str | None
    pokemon_name: str | None


type VariantTransform = Literal["color", "sharpen", "threshold"]


class OCRItem(TypedDict):
    text: str
    raw_text: str
    score: float
    box: object | None
    variant: NotRequired[str]


class TrainerItem(OCRItem):
    crop_ratio: float


class RegionRecognizerDiagnostics(TypedDict):
    seconds: float
    timings: dict[str, float]
    items: Sequence[OCRItem]


class FastRecognizerDiagnostics(TypedDict):
    seconds: float
    raw_results: list[object]
    candidate: OCRItem | None


class VariantStep(TypedDict):
    name: str
    pad_ratio: float
    scale: float
    transform: VariantTransform


class PokemonVariantStep(VariantStep):
    left_ratio: float


class TrainerVariantStep(VariantStep):
    right_ratio: float


class TitleVariantStep(VariantStep):
    crop: Literal["standard", "wide", "lower_wide"]


POKEMON_VARIANT_STEPS: list[PokemonVariantStep] = [
    {
        "name": "pokemon_color_fast",
        "left_ratio": 0.30,
        "pad_ratio": 0.08,
        "scale": 1.0,
        "transform": "color",
    },
    {
        "name": "pokemon_color_balanced",
        "left_ratio": 0.30,
        "pad_ratio": 0.08,
        "scale": 1.25,
        "transform": "color",
    },
    {
        "name": "pokemon_color_large",
        "left_ratio": 0.30,
        "pad_ratio": 0.08,
        "scale": 1.75,
        "transform": "color",
    },
    {
        "name": "pokemon_sharpened_large",
        "left_ratio": 0.30,
        "pad_ratio": 0.08,
        "scale": 1.75,
        "transform": "sharpen",
    },
    {
        "name": "pokemon_sharpened_xl",
        "left_ratio": 0.30,
        "pad_ratio": 0.08,
        "scale": 2.0,
        "transform": "sharpen",
    },
]

TRAINER_VARIANT_STEPS: list[TrainerVariantStep] = [
    {
        "name": "trainer_color_tight",
        "right_ratio": 0.24,
        "pad_ratio": 0.08,
        "scale": 1.0,
        "transform": "color",
    },
    {
        "name": "trainer_color_fast",
        "right_ratio": 0.26,
        "pad_ratio": 0.08,
        "scale": 1.0,
        "transform": "color",
    },
    {
        "name": "trainer_color_balanced",
        "right_ratio": 0.28,
        "pad_ratio": 0.08,
        "scale": 1.25,
        "transform": "color",
    },
    {
        "name": "trainer_sharpened",
        "right_ratio": 0.30,
        "pad_ratio": 0.08,
        "scale": 1.5,
        "transform": "sharpen",
    },
]

TITLE_VARIANT_STEPS: list[TitleVariantStep] = [
    {
        "name": "standard_color_fast",
        "crop": "standard",
        "pad_ratio": 0.05,
        "scale": 1.0,
        "transform": "color",
    },
    {
        "name": "wide_color_fast",
        "crop": "wide",
        "pad_ratio": 0.05,
        "scale": 1.0,
        "transform": "color",
    },
    {
        "name": "standard_color_balanced",
        "crop": "standard",
        "pad_ratio": 0.08,
        "scale": 1.1,
        "transform": "color",
    },
    {
        "name": "wide_color_balanced",
        "crop": "wide",
        "pad_ratio": 0.08,
        "scale": 1.15,
        "transform": "color",
    },
    {
        "name": "lower_wide_color_balanced",
        "crop": "lower_wide",
        "pad_ratio": 0.08,
        "scale": 1.5,
        "transform": "color",
    },
    {
        "name": "wide_sharpened_fallback",
        "crop": "wide",
        "pad_ratio": 0.12,
        "scale": 1.5,
        "transform": "sharpen",
    },
    {
        "name": "lower_wide_sharpened_fallback",
        "crop": "lower_wide",
        "pad_ratio": 0.12,
        "scale": 1.5,
        "transform": "sharpen",
    },
    {
        "name": "wide_threshold_fallback",
        "crop": "wide",
        "pad_ratio": 0.12,
        "scale": 1.5,
        "transform": "threshold",
    },
]


class PokemonCardsOcr:
    def get_information(
        self, image: bytes, language: str | None = None
    ) -> PokemonCardInformation:
        card_image = self.__decode_image(image)
        fallback_languages = self.__get_fallback_languages(language)
        name_crop = self.__crop_name_region(card_image)
        wide_name_crop = self.__crop_wide_name_region(card_image)
        lower_wide_name_crop = self.__crop_lower_wide_name_region(card_image)
        self.__maybe_write_debug_image("01_name_crop.jpg", name_crop)
        self.__maybe_write_debug_image("01_wide_name_crop.jpg", wide_name_crop)
        self.__maybe_write_debug_image(
            "01_lower_wide_name_crop.jpg", lower_wide_name_crop
        )

        fast_candidate, _ = self.__run_fast_recognizer(name_crop)
        best_title_candidate: OCRItem | None = None
        best_trainer_candidate: TrainerItem | None = None
        best_pokemon_candidate = fast_candidate
        title_items: list[OCRItem] = []
        pokemon_items = [fast_candidate] if fast_candidate is not None else []

        used_split_fallback = not self.__is_confident_candidate(
            best_pokemon_candidate, FAST_RECOGNIZER_MIN_SCORE
        )
        if used_split_fallback:
            trainer_items, _ = self.__run_trainer_recognizer(name_crop)
            pokemon_region_items, _ = self.__run_pokemon_recognizer(name_crop)
            pokemon_items.extend(pokemon_region_items)

            best_trainer_candidate = self.__choose_best_trainer_candidate(trainer_items)
            best_pokemon_candidate = self.__choose_best_name_candidate(
                pokemon_region_items
            ) or self.__choose_best_name_candidate(pokemon_items)

            if self.__should_run_title_ocr(
                trainer_items,
                best_trainer_candidate,
                pokemon_items,
                best_pokemon_candidate,
            ):
                title_items = self.__run_title_ocr(
                    name_crop,
                    wide_name_crop,
                    lower_wide_name_crop,
                    fallback_languages,
                )
                best_title_candidate = self.__choose_best_title_candidate(title_items)

        title_parts = self.__split_title_candidate(best_title_candidate)
        if title_parts is not None:
            trainer_name, pokemon_name = title_parts
            full_title = (
                best_title_candidate["text"]
                if best_title_candidate is not None
                else pokemon_name
            )
            return PokemonCardInformation(
                full_title=full_title,
                trainer_name=trainer_name,
                pokemon_name=pokemon_name,
            )

        if self.__should_prefer_title_for_pokemon(
            best_title_candidate,
            best_trainer_candidate,
            best_pokemon_candidate,
            pokemon_items,
        ):
            best_pokemon_candidate = best_title_candidate

        if self.__should_drop_trainer_candidate(
            best_title_candidate,
            best_trainer_candidate,
        ):
            best_trainer_candidate = None

        trainer_name = (
            best_trainer_candidate["text"]
            if best_trainer_candidate is not None
            else None
        )
        pokemon_name = (
            best_pokemon_candidate["text"]
            if best_pokemon_candidate is not None
            else None
        )
        full_title = (
            best_title_candidate["text"]
            if best_title_candidate is not None
            else self.__build_combined_name(trainer_name, pokemon_name)
        )

        return PokemonCardInformation(
            full_title=full_title,
            trainer_name=trainer_name,
            pokemon_name=pokemon_name,
        )

    def __get_fallback_languages(self, language: str | None) -> tuple[str, ...]:
        if language is None:
            return FALLBACK_LANGUAGES
        if language not in FALLBACK_LANGUAGES:
            supported_languages = ", ".join(FALLBACK_LANGUAGES)
            raise ValueError(
                f"Unsupported OCR language {language!r}. "
                f"Expected one of: {supported_languages}."
            )
        return (language,)

    def __decode_image(self, image: bytes) -> np.ndarray:
        encoded_image = np.frombuffer(image, dtype=np.uint8)
        decoded_image = cv2.imdecode(encoded_image, cv2.IMREAD_COLOR)
        if decoded_image is None:
            raise ValueError("Invalid or unreadable image bytes.")
        return decoded_image

    def __run_pokemon_recognizer(
        self,
        name_crop: np.ndarray,
    ) -> tuple[list[OCRItem], RegionRecognizerDiagnostics]:
        recognizer = self.__get_text_recognizer(FAST_RECOGNIZER_MODEL)
        pokemon_items: list[OCRItem] = []
        pokemon_timings: dict[str, float] = {}
        pokemon_start = perf_counter()

        for step in POKEMON_VARIANT_STEPS:
            variant_name = step["name"]
            pokemon_crop = self.__crop_pokemon_name_region(
                name_crop, step["left_ratio"]
            )
            variant_image = self.__build_variant(
                pokemon_crop,
                pad_ratio=step["pad_ratio"],
                scale=step["scale"],
                transform=step["transform"],
            )
            self.__maybe_write_debug_image(f"variant_{variant_name}.jpg", variant_image)

            variant_start = perf_counter()
            results = list(recognizer.predict(variant_image))
            pokemon_timings[variant_name] = round(perf_counter() - variant_start, 3)

            if not results:
                continue

            first_result = results[0]
            raw_text = first_result["rec_text"]
            normalized_text = self.__cleanup_text(raw_text)
            if not self.__looks_like_name_text(normalized_text):
                continue

            pokemon_items.append(
                OCRItem(
                    text=normalized_text,
                    raw_text=raw_text,
                    score=float(first_result["rec_score"]),
                    box=None,
                    variant=variant_name,
                )
            )

        diagnostics: RegionRecognizerDiagnostics = {
            "seconds": round(perf_counter() - pokemon_start, 3),
            "timings": pokemon_timings,
            "items": pokemon_items,
        }
        return pokemon_items, diagnostics

    def __run_trainer_recognizer(
        self,
        name_crop: np.ndarray,
    ) -> tuple[list[TrainerItem], RegionRecognizerDiagnostics]:
        recognizer = self.__get_text_recognizer(FAST_RECOGNIZER_MODEL)
        trainer_items: list[TrainerItem] = []
        trainer_timings: dict[str, float] = {}
        trainer_start = perf_counter()

        for step in TRAINER_VARIANT_STEPS:
            variant_name = step["name"]
            trainer_crop = self.__crop_trainer_name_region(
                name_crop, step["right_ratio"]
            )
            variant_image = self.__build_variant(
                trainer_crop,
                pad_ratio=step["pad_ratio"],
                scale=step["scale"],
                transform=step["transform"],
            )
            self.__maybe_write_debug_image(f"variant_{variant_name}.jpg", variant_image)

            variant_start = perf_counter()
            results = list(recognizer.predict(variant_image))
            trainer_timings[variant_name] = round(perf_counter() - variant_start, 3)

            if not results:
                continue

            first_result = results[0]
            raw_text = first_result["rec_text"]
            normalized_text = self.__cleanup_text(raw_text)
            if not self.__looks_like_name_text(normalized_text):
                continue

            trainer_items.append(
                TrainerItem(
                    text=normalized_text,
                    raw_text=raw_text,
                    score=float(first_result["rec_score"]),
                    box=None,
                    variant=variant_name,
                    crop_ratio=step["right_ratio"],
                )
            )

        diagnostics: RegionRecognizerDiagnostics = {
            "seconds": round(perf_counter() - trainer_start, 3),
            "timings": trainer_timings,
            "items": trainer_items,
        }
        return trainer_items, diagnostics

    def __run_fast_recognizer(
        self,
        name_crop: np.ndarray,
    ) -> tuple[OCRItem | None, FastRecognizerDiagnostics]:
        recognizer = self.__get_text_recognizer(FAST_RECOGNIZER_MODEL)
        fast_crop = self.__upscale(self.__crop_fast_name_line(name_crop), 1.25)
        self.__maybe_write_debug_image("variant_fast_recognizer.jpg", fast_crop)

        fast_start = perf_counter()
        results = list(recognizer.predict(fast_crop))
        elapsed = round(perf_counter() - fast_start, 3)

        rec_text = ""
        rec_score = 0.0
        raw_text = ""
        if results:
            first_result = results[0]
            raw_text = first_result["rec_text"]
            rec_text = self.__cleanup_text(raw_text)
            rec_score = float(first_result["rec_score"])

        candidate: OCRItem | None = None
        if self.__looks_like_name_text(rec_text):
            candidate = OCRItem(
                text=rec_text,
                raw_text=raw_text,
                score=rec_score,
                box=None,
                variant="fast_recognizer",
            )

        diagnostics: FastRecognizerDiagnostics = {
            "seconds": elapsed,
            "raw_results": results,
            "candidate": candidate,
        }
        return candidate, diagnostics

    def __run_title_ocr(
        self,
        name_crop: np.ndarray,
        wide_name_crop: np.ndarray,
        lower_wide_name_crop: np.ndarray,
        fallback_languages: Sequence[str],
    ) -> list[OCRItem]:
        title_items: list[OCRItem] = []

        for language in fallback_languages:
            card_ocr = self.__get_card_ocr(language)
            for step in TITLE_VARIANT_STEPS:
                source_image = self.__get_title_source_image(
                    step["crop"], name_crop, wide_name_crop, lower_wide_name_crop
                )
                variant_name = f"{language}_{step['name']}"
                variant_image = self.__build_variant(
                    source_image,
                    pad_ratio=step["pad_ratio"],
                    scale=step["scale"],
                    transform=step["transform"],
                )
                self.__maybe_write_debug_image(
                    f"variant_{variant_name}.jpg", variant_image
                )

                result = card_ocr.predict(
                    variant_image,
                    use_doc_orientation_classify=False,
                    use_doc_unwarping=False,
                    use_textline_orientation=False,
                )

                items = self.__extract_ocr_items(result)
                for item in items:
                    item["variant"] = variant_name

                title_items.extend(items)
                best_title_candidate = self.__choose_best_title_candidate(title_items)
                if (
                    best_title_candidate is not None
                    and best_title_candidate["score"] >= MIN_CONFIDENT_SCORE
                    and self.__has_supported_script(best_title_candidate["text"])
                ):
                    return title_items

        return title_items

    def __get_title_source_image(
        self,
        crop: str,
        name_crop: np.ndarray,
        wide_name_crop: np.ndarray,
        lower_wide_name_crop: np.ndarray,
    ) -> np.ndarray:
        if crop == "wide":
            return wide_name_crop
        if crop == "lower_wide":
            return lower_wide_name_crop
        return name_crop

    def __extract_ocr_items(self, ocr_result: Iterable[OCRResult]) -> list[OCRItem]:
        items: list[OCRItem] = []
        for page in ocr_result:
            for text, score, box in zip(
                page["rec_texts"], page["rec_scores"], page["rec_boxes"]
            ):
                items.append(
                    OCRItem(
                        text=text,
                        raw_text=text,
                        score=float(score),
                        box=box.tolist() if hasattr(box, "tolist") else box,
                    )
                )
        return items

    def __choose_best_name_candidate(self, ocr_items: list[OCRItem]) -> OCRItem | None:
        candidates: list[OCRItem] = []
        for item in ocr_items:
            normalized_text = self.__cleanup_text(item["text"])
            if not self.__looks_like_name_text(normalized_text):
                continue
            candidates.append({**item, "text": normalized_text})
        if not candidates:
            return None

        return max(candidates, key=self.__score_name_candidate)

    def __choose_best_title_candidate(self, ocr_items: list[OCRItem]) -> OCRItem | None:
        candidates: list[OCRItem] = []
        for item in ocr_items:
            normalized_text = self.__cleanup_text(item["text"])
            if not self.__looks_like_name_text(normalized_text, min_length=1):
                continue
            if not self.__has_supported_script(normalized_text):
                continue
            candidates.append({**item, "text": normalized_text})
        if not candidates:
            return None

        return max(
            candidates,
            key=lambda item: (
                self.__title_joiner_score(item["text"]),
                self.__script_score(item["text"]),
                item["score"],
                len(item["text"]),
            ),
        )

    def __choose_best_trainer_candidate(
        self,
        ocr_items: list[TrainerItem],
    ) -> TrainerItem | None:
        candidates: list[TrainerItem] = []
        for item in ocr_items:
            normalized_text = self.__cleanup_text(item["text"])
            if not self.__looks_like_name_text(normalized_text, min_length=1):
                continue
            candidates.append({**item, "text": normalized_text})
        if not candidates:
            return None

        ordered_candidates = sorted(
            candidates, key=lambda item: item.get("crop_ratio", 1.0)
        )
        stable_prefix = self.__longest_common_prefix(
            [item["text"] for item in ordered_candidates]
        )
        best_candidate = max(
            candidates,
            key=lambda item: (
                item["score"],
                -item.get("crop_ratio", 1.0),
                len(item["text"]),
            ),
        )

        if self.__looks_like_name_text(stable_prefix, min_length=1):
            candidate: TrainerItem = {
                "text": stable_prefix,
                "raw_text": best_candidate["raw_text"],
                "score": best_candidate["score"],
                "box": best_candidate["box"],
                "crop_ratio": best_candidate["crop_ratio"],
            }
            if "variant" in best_candidate:
                candidate["variant"] = best_candidate["variant"]
            return candidate

        return best_candidate

    def __should_run_title_ocr(
        self,
        trainer_items: Sequence[OCRItem],
        best_trainer_candidate: OCRItem | None,
        pokemon_items: Sequence[OCRItem],
        best_pokemon_candidate: OCRItem | None,
    ) -> bool:
        trainer_is_reliable = self.__is_confident_candidate(
            best_trainer_candidate
        ) or self.__is_supported_candidate(
            best_trainer_candidate,
            trainer_items,
        )
        pokemon_is_reliable = self.__is_confident_candidate(
            best_pokemon_candidate
        ) or self.__is_supported_candidate(
            best_pokemon_candidate,
            pokemon_items,
        )
        return not (trainer_is_reliable and pokemon_is_reliable)

    def __should_prefer_title_for_pokemon(
        self,
        best_title_candidate: OCRItem | None,
        best_trainer_candidate: OCRItem | None,
        best_pokemon_candidate: OCRItem | None,
        pokemon_items: Sequence[OCRItem],
    ) -> bool:
        if best_title_candidate is None:
            return False
        if best_pokemon_candidate is None:
            return True
        if best_trainer_candidate is not None and self.__title_has_trainer_joiner(
            best_title_candidate["text"]
        ):
            return False
        if not self.__is_confident_candidate(best_pokemon_candidate):
            return True
        return not self.__is_supported_candidate(best_pokemon_candidate, pokemon_items)

    def __should_drop_trainer_candidate(
        self,
        best_title_candidate: OCRItem | None,
        best_trainer_candidate: OCRItem | None,
    ) -> bool:
        if best_title_candidate is None or best_trainer_candidate is None:
            return False
        if self.__title_has_trainer_joiner(best_title_candidate["text"]):
            return False
        return best_title_candidate["text"].startswith(
            best_trainer_candidate["text"]
        ) and len(best_title_candidate["text"]) > len(best_trainer_candidate["text"])

    def __split_title_candidate(
        self, candidate: OCRItem | None
    ) -> tuple[str | None, str] | None:
        if candidate is None:
            return None

        title = candidate["text"]
        for joiner in ("の", "의", "的"):
            if joiner not in title:
                continue
            trainer_name, pokemon_name = title.split(joiner, 1)
            trainer_name = self.__cleanup_text(trainer_name)
            pokemon_name = self.__cleanup_text(pokemon_name)
            if self.__looks_like_name_text(
                trainer_name, min_length=1
            ) and self.__looks_like_name_text(pokemon_name):
                return trainer_name, pokemon_name

        if self.__looks_like_name_text(title):
            return None, title

        return None

    def __is_supported_candidate(
        self,
        candidate: OCRItem | None,
        ocr_items: Sequence[OCRItem],
        min_support: int = 2,
    ) -> bool:
        if candidate is None:
            return False
        return self.__count_text_support(ocr_items, candidate["text"]) >= min_support

    def __count_text_support(self, ocr_items: Sequence[OCRItem], text: str) -> int:
        normalized_text = self.__cleanup_text(text)
        return sum(
            1
            for item in ocr_items
            if self.__cleanup_text(item["text"]) == normalized_text
        )

    def __is_confident_candidate(
        self, candidate: OCRItem | None, min_score: float = MIN_CONFIDENT_SCORE
    ) -> bool:
        if candidate is None:
            return False
        script_count = len(
            re.findall(r"[\u4e00-\u9fff가-힣ァ-ンーA-Za-z]", candidate["text"])
        )
        return script_count >= 3 and candidate["score"] >= min_score

    def __build_combined_name(
        self,
        trainer_name: str | None,
        pokemon_name: str | None,
    ) -> str | None:
        if trainer_name is None:
            return pokemon_name
        if pokemon_name is None:
            return trainer_name

        return f"{trainer_name}の{pokemon_name}"

    def __title_has_trainer_joiner(self, text: str) -> bool:
        return any(joiner in text for joiner in ("の", "의", "的"))

    def __longest_common_prefix(self, texts: list[str]) -> str:
        if not texts:
            return ""

        prefix = texts[0]
        for text in texts[1:]:
            while prefix and not text.startswith(prefix):
                prefix = prefix[:-1]
            if not prefix:
                break

        return prefix.rstrip()

    def __score_name_candidate(self, item: OCRItem) -> tuple[int, int, int, float]:
        text = item["text"]
        latin_count = len(re.findall(r"[A-Za-z]", text))
        return (
            self.__script_score(text),
            -latin_count,
            len(text),
            item["score"],
        )

    def __script_score(self, text: str) -> int:
        han_count = len(re.findall(r"[\u4e00-\u9fff]", text))
        hangul_count = len(re.findall(r"[가-힣]", text))
        katakana_count = len(re.findall(r"[ァ-ンー]", text))
        return (han_count + hangul_count + katakana_count) * 10

    def __title_joiner_score(self, text: str) -> int:
        if self.__title_has_trainer_joiner(text):
            return 20
        return 0

    def __has_supported_script(self, text: str) -> bool:
        return bool(re.search(r"[\u4e00-\u9fff가-힣ァ-ンー]", text))

    def __build_variant(
        self,
        image: np.ndarray,
        *,
        pad_ratio: float,
        scale: float,
        transform: str = "color",
    ) -> np.ndarray:
        variant = self.__upscale(self.__add_padding(image, pad_ratio), scale)
        if transform == "sharpen":
            return self.__sharpen(variant)
        if transform == "threshold":
            return self.__threshold_dark_text(variant)
        return variant

    def __threshold_dark_text(self, image: np.ndarray) -> np.ndarray:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (3, 3), 0)
        _, mask = cv2.threshold(
            gray,
            0,
            255,
            cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU,
        )
        kernel = np.ones((2, 2), np.uint8)
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        white_bg = 255 - mask
        return cv2.cvtColor(white_bg, cv2.COLOR_GRAY2BGR)

    def __sharpen(self, image: np.ndarray) -> np.ndarray:
        kernel = np.array(
            [
                [0, -1, 0],
                [-1, 5, -1],
                [0, -1, 0],
            ]
        )
        return cv2.filter2D(image, -1, kernel)

    def __add_padding(self, image: np.ndarray, pad_ratio: float) -> np.ndarray:
        h, w = image.shape[:2]
        pad_y = int(h * pad_ratio)
        pad_x = int(w * pad_ratio)
        return cv2.copyMakeBorder(
            image,
            pad_y,
            pad_y,
            pad_x,
            pad_x,
            borderType=cv2.BORDER_REPLICATE,
        )

    def __crop_trainer_name_region(
        self, image: np.ndarray, right_ratio: float
    ) -> np.ndarray:
        _, w = image.shape[:2]
        x2 = int(w * right_ratio)
        return image[:, :x2]

    def __crop_pokemon_name_region(
        self, image: np.ndarray, left_ratio: float
    ) -> np.ndarray:
        _, w = image.shape[:2]
        x1 = int(w * left_ratio)
        return image[:, x1:]

    def __crop_name_region(self, image: np.ndarray) -> np.ndarray:
        h, w = image.shape[:2]
        x1 = int(w * 0.20)
        x2 = int(w * 0.68)
        y1 = int(h * 0.035)
        y2 = int(h * 0.115)
        return image[y1:y2, x1:x2]

    def __crop_wide_name_region(self, image: np.ndarray) -> np.ndarray:
        h, w = image.shape[:2]
        x1 = int(w * 0.12)
        x2 = int(w * 0.74)
        y1 = int(h * 0.025)
        y2 = int(h * 0.125)
        return image[y1:y2, x1:x2]

    def __crop_lower_wide_name_region(self, image: np.ndarray) -> np.ndarray:
        h, w = image.shape[:2]
        x1 = int(w * 0.12)
        x2 = int(w * 0.72)
        y1 = int(h * 0.10)
        y2 = int(h * 0.24)
        return image[y1:y2, x1:x2]

    def __looks_like_name_text(self, text: str, min_length: int = 2) -> bool:
        text = self.__cleanup_text(text)
        if len(text) < min_length:
            return False
        if not re.search(r"[\u4e00-\u9fff가-힣ァ-ンーA-Za-z]", text):
            return False
        bad_fragments = ["进化", "从", "進化", "から", "진화", "에서", "HP", "NO"]
        return not any(fragment in text for fragment in bad_fragments)

    def __cleanup_text(self, text: str) -> str:
        text = re.sub(r"\s+", " ", text.strip())
        text = re.sub(r"[・·•]+$", "", text)

        trailing_mechanic_pattern = r"(?:ex|gx|vmax|vstar|v-union|lv\.?x|v)"
        if re.search(
            rf"[\u4e00-\u9fff가-힣ァ-ンー]\s*{trailing_mechanic_pattern}$",
            text,
            flags=re.IGNORECASE,
        ):
            text = re.sub(
                rf"\s*{trailing_mechanic_pattern}$",
                "",
                text,
                flags=re.IGNORECASE,
            )
        elif re.search(r"[\u4e00-\u9fff가-힣ァ-ンー]\s*[A-Za-z]$", text):
            text = re.sub(r"\s*[A-Za-z]$", "", text)

        return text.strip()

    def __maybe_write_debug_image(self, name: str, image: np.ndarray) -> None:
        if WRITE_DEBUG_IMAGES:
            cv2.imwrite(str(debug_path / name), image)

    def __crop_fast_name_line(self, image: np.ndarray) -> np.ndarray:
        h, w = image.shape[:2]
        y2 = int(h * 0.68)
        x2 = int(w * 0.90)
        line_crop = image[:y2, :x2]
        return cv2.copyMakeBorder(
            line_crop,
            10,
            10,
            20,
            20,
            borderType=cv2.BORDER_REPLICATE,
        )

    def __get_text_recognizer(self, model_name: str):
        text_recognizer = _TEXT_RECOGNIZER_CACHE.get(model_name)
        if text_recognizer is None:
            text_recognizer = create_model(model_name)
            _TEXT_RECOGNIZER_CACHE[model_name] = text_recognizer
            globals()["_TEXT_RECOGNIZER_CACHE"] = _TEXT_RECOGNIZER_CACHE
        return text_recognizer

    def __get_card_ocr(self, language: str) -> PaddleOCR:
        card_ocr = _OCR_CACHE.get(language)
        if card_ocr is None:
            card_ocr = PaddleOCR(
                lang=language,
                use_doc_orientation_classify=False,
                use_doc_unwarping=False,
                use_textline_orientation=False,
            )
            _OCR_CACHE[language] = card_ocr
            globals()["_OCR_CACHE"] = _OCR_CACHE
        return card_ocr

    def __upscale(self, image: np.ndarray, scale: float) -> np.ndarray:
        return cv2.resize(
            image,
            None,
            fx=scale,
            fy=scale,
            interpolation=cv2.INTER_CUBIC,
        )
