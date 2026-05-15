from dataclasses import asdict
from pathlib import Path

from pokemon_cards import PokemonCardInformation, PokemonCardsOcr


REPO_ROOT = Path(__file__).resolve().parents[2]
CARD_IMAGE_SAMPLE = REPO_ROOT / "samples" / "trainers-snorlax.jpg"


def run(
    card_image_sample: Path = CARD_IMAGE_SAMPLE, language: str | None = None
) -> PokemonCardInformation:
    card_image_path = Path(card_image_sample)
    image = card_image_path.read_bytes()
    information = PokemonCardsOcr().get_information(image, language)
    print(asdict(information))
    return information


def main() -> PokemonCardInformation:
    return run()


if __name__ == "__main__":
    main()
