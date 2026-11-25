import json
import sys
from pathlib import Path


def convert_chart(input_path: str, output_path: str | None = None) -> Path:
    in_file = Path(input_path)
    out_file = (
        Path(output_path)
        if output_path
        else in_file.with_name(f"{in_file.stem}_converted.json")
    )

    with in_file.open("r", encoding="utf-8") as f:
        data = json.load(f)

    # Support both wrapped {"song": {...}} and unwrapped chart JSONs
    song_in = data["song"] if isinstance(data.get("song"), dict) else data

    notes_out = []
    for sec in song_in.get("notes", []):
        section_obj = {
            "sectionNotes": sec.get("sectionNotes", []),
            "lengthInSteps": sec.get("lengthInSteps", 16),
            "typeOfSection": sec.get("typeOfSection", 0),
            "altAnim": sec.get("altAnim", False),
            "mustHitSection": sec.get("mustHitSection", False),
            "changeBPM": sec.get("changeBPM", False),
        }
        if "bpm" in sec:
            section_obj["bpm"] = sec["bpm"]
        notes_out.append(section_obj)

    bpm = song_in.get("bpm", 100)

    song_out = {
        "sectionLengths": [],
        "player1": song_in.get("player1", "bf"),
        "player2": song_in.get("player2", "dad"),
        "notes": notes_out,
        "gfVersion": song_in.get("gfVersion", "gf"),
        "song": song_in.get("song", in_file.stem),
        "validScore": True,
        "sections": 0,
        "stage": song_in.get("stage", "stage"),
        "needsVoices": song_in.get("needsVoices", False),
        "speed": song_in.get("speed", 1),
        "bpm": bpm,
    }

    converted = {
        "notes": notes_out,
        "sections": len(notes_out),
        "bpm": bpm,
        "song": song_out,
    }

    with out_file.open("w", encoding="utf-8") as f:
        json.dump(converted, f, separators=(",", ":"))

    return out_file


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python convert_chart.py <input.json> [output.json]")
        sys.exit(1)

    out = convert_chart(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    print(f"Saved converted chart to: {out}")
