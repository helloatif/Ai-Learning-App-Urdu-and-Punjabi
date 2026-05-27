from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets' / 'data' / 'combined_training_dataset_with_lessons.json'
OUTPUT_DIR = ROOT / 'tools' / 'firehose_exports'


def _load_dataset() -> dict:
    return json.loads(SOURCE.read_text(encoding='utf-8-sig'))


def _native_chapter_title(chapter: dict, language: str) -> str:
    if language == 'urdu':
        return chapter.get('chapter_name_urdu') or chapter.get('chapter_name') or ''
    return chapter.get('chapter_name_punjabi') or chapter.get('chapter_name') or ''


def _lesson_words(lesson: dict) -> list[dict]:
    words: list[dict] = []
    for item in lesson.get('vocabulary', []):
        words.append(
            {
                'urdu': item.get('word', ''),
                'english': item.get('translation', ''),
                'pronunciation': item.get('pronunciation', ''),
                'exampleSentence': item.get('example'),
                'exampleEnglish': item.get('example_translation'),
                'difficulty': item.get('difficulty'),
            },
        )
    return words


def build_exports() -> tuple[list[dict], dict[str, dict]]:
    data = _load_dataset()
    metadata = data.get('metadata', {})
    chapters_by_language = data.get('chapters', {})

    chapter_docs: list[dict] = []
    lessons_import: dict[str, dict] = {}

    for language, chapters in chapters_by_language.items():
        for chapter_number, chapter in enumerate(chapters, start=1):
            chapter_id = chapter['chapter_id']
            lessons = chapter.get('lessons', [])
            total_words = sum(len(lesson.get('vocabulary', [])) for lesson in lessons)

            chapter_docs.append(
                {
                    'chapter_id': chapter_id,
                    'chapter_number': chapter_number,
                    'language': language,
                    'title': _native_chapter_title(chapter, language),
                    'titleEnglish': chapter.get('chapter_name', ''),
                    'chapter_name': chapter.get('chapter_name', ''),
                    'chapter_name_urdu': chapter.get('chapter_name_urdu'),
                    'chapter_name_punjabi': chapter.get('chapter_name_punjabi'),
                    'description': chapter.get('description', ''),
                    'lessonCount': len(lessons),
                    'wordsPerChapter': total_words,
                    'quizMcqCount': len(chapter.get('quiz', {}).get('mcq', [])),
                    'quizUserInputCount': len(chapter.get('quiz', {}).get('user_input', [])),
                    'script': metadata.get('script', {}).get(language),
                },
            )

            lessons_import[f'chapters/{chapter_id}/lessons'] = {
                'id field name': 'lesson_id',
                'data': [
                    {
                        'lesson_id': lesson['lesson_id'],
                        'lessonNumber': lesson.get('lesson_number', 0),
                        'title': lesson.get('lesson_name', ''),
                        'titleEnglish': lesson.get('lesson_name', ''),
                        'words': _lesson_words(lesson),
                    }
                    for lesson in lessons
                ],
            }

    return chapter_docs, lessons_import


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    chapters, lessons = build_exports()

    (OUTPUT_DIR / 'chapters.json').write_text(
        json.dumps(chapters, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )
    (OUTPUT_DIR / 'lessons.json').write_text(
        json.dumps(lessons, ensure_ascii=False, indent=2),
        encoding='utf-8',
    )

    print(f'Wrote {len(chapters)} chapter docs to {OUTPUT_DIR / "chapters.json"}')
    print(f'Wrote {len(lessons)} lesson collections to {OUTPUT_DIR / "lessons.json"}')


if __name__ == '__main__':
    main()