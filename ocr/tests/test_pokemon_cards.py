from dataclasses import asdict
from collections.abc import Callable
from pathlib import Path

import pytest

from pokemon_cards import PokemonCardsOcr


REPO_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="session")
def pokemon_cards_ocr() -> PokemonCardsOcr:
    return PokemonCardsOcr()


@pytest.fixture
def sample_card_image() -> Callable[[str], bytes]:
    def read_sample_card_image(sample_name: str) -> bytes:
        return (REPO_ROOT / "samples" / sample_name).read_bytes()

    return read_sample_card_image


@pytest.mark.parametrize(
    ("sample_name", "expected_information"),
    [
        (
            "eevee.jpg",
            {
                "full_title": "이브이",
                "trainer_name": None,
                "pokemon_name": "이브이",
            },
        ),
        (
            "insect-chinese.jpg",
            {
                "full_title": "音箱蟀",
                "trainer_name": None,
                "pokemon_name": "音箱蟀",
            },
        ),
        (
            "shiny-charmeleon.jpg",
            {
                "full_title": "リザード",
                "trainer_name": None,
                "pokemon_name": "リザード",
            },
        ),
        (
            "trainers-ghost.jpg",
            {
                "full_title": "黑夜魔靈",
                "trainer_name": None,
                "pokemon_name": "黑夜魔靈",
            },
        ),
        (
            "trainers-snorlax.jpg",
            {
                "full_title": "ホップのカビゴン",
                "trainer_name": "ホップ",
                "pokemon_name": "カビゴン",
            },
        ),
        (
            "trainers-wold.jpg",
            {
                "full_title": "Nのゾロアーク",
                "trainer_name": "N",
                "pokemon_name": "ゾロアーク",
            },
        ),
    ],
)
def test_get_information_extracts_sample_card_names(
    pokemon_cards_ocr: PokemonCardsOcr,
    sample_card_image: Callable[[str], bytes],
    sample_name: str,
    expected_information: dict[str, str | None],
) -> None:
    image = sample_card_image(sample_name)

    information = pokemon_cards_ocr.get_information(image)

    assert asdict(information) == expected_information


def test_get_information_accepts_language_to_limit_fallback_ocr(
    pokemon_cards_ocr: PokemonCardsOcr,
    sample_card_image: Callable[[str], bytes],
) -> None:
    information = pokemon_cards_ocr.get_information(
        sample_card_image("trainers-wold.jpg"), language="japan"
    )

    assert asdict(information) == {
        "full_title": "Nのゾロアーク",
        "trainer_name": "N",
        "pokemon_name": "ゾロアーク",
    }


def test_get_information_rejects_invalid_image_bytes(
    pokemon_cards_ocr: PokemonCardsOcr,
) -> None:
    with pytest.raises(ValueError, match="Invalid or unreadable image bytes"):
        pokemon_cards_ocr.get_information(b"not an image")
