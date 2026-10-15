# Gemini Prompts in SudyAI

Source: the `GeminiService` class in `StudyIOS/StudyIOSApp.swift`.

- **Model:** `gemini-2.5-flash`
- **Endpoint:** `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={API_KEY}`
- Constructs like `\(name)` are Swift string interpolation: the variable's value is substituted before the request is sent.
- Methods 1–4 use structured output (`responseMimeType: application/json` + `responseSchema`); methods 5–6 return free-form text.

---

## 1. `generateLesson` — textbook-curriculum lesson generation

**Triggered by:** the "Generate Custom Lesson" button on the Learn tab.

**Variables:** `targetLanguage` (English/German), `difficulty` (A1–C1), `nativeLanguageName` (Russian/English/German), `completedLessons` (titles of finished lessons), `studiedWords` (learned words, when AI Memory is enabled).

**Prompt** (the first line depends on the target language):

For English:
```
Act as an expert English teacher following the curriculum structure of the book 'English File (Fifth Edition) — Oxford University Press' for CEFR level \(difficulty).
```
For German:
```
Act as an expert German teacher following the curriculum structure of the textbook series published by 'Hueber Verlag' (e.g. Menschen, Schritte, or Sicher) for CEFR level \(difficulty).
```

Followed by the shared body:
```
You are a friendly, highly professional, and detailed private language tutor. Your goal is to completely replace a human teacher by providing structured, thorough, and engaging lessons.

Target language: \(targetLanguage).
Target difficulty level: \(difficulty).
User's native language (to write explanations in): \(nativeLanguageName).

Generate a comprehensive, structured course lesson.

The lesson must include:
1. A Lesson Title indicating the unit/topic from the curriculum (e.g. "English File: Unit 3A - Present Perfect" or "Hueber Menschen: Lektion 4 - Nebensätze").
2. A thorough, detailed, and beautifully structured Grammar Focus Lecture. Do NOT write a brief summary. Explain the grammar rules in depth, detailing verb structures, cases, tenses, word order, and specifically highlighting common pitfalls and mistakes made by native \(nativeLanguageName) speakers. Use clear comparisons and structural examples.
3. A list of 8 to 12 core vocabulary words or idiomatic phrases relevant to this grammatical unit, everyday life, and the life/IT work of a software engineer relocating to Germany. This is the full vocabulary portion of the lesson, so make it substantial.
4. A realistic, extended dialogue (roughly 10 to 16 lines) or reading text in \(targetLanguage) applying this grammar topic in a professional (IT standup, code review) or relocation context (renting, registrations), along with a side-by-side native \(nativeLanguageName) translation. The dialogue must actively use ALL the vocabulary words generated in step 3.
5. A practice quiz containing 4 to 6 multiple-choice exercises testing both the vocabulary and the grammar rules taught. The options must be in \(targetLanguage). The explanation of correct choices must be written in detail in \(nativeLanguageName), explaining why other options are incorrect.

CRITICAL RULES:
- Do NOT include any HTML tags (such as <ul>, <li>, <br>, <b>) in any string parameter.
- For lists, points, or formatting in the grammar explanation, use only standard Markdown (e.g. asterisks '*' or hyphens '-' for bullet points, double asterisks for bolding, and newlines '\n').
- All translations, explanations of grammar, and explanations of quiz answers must be written in the user's native language (\(nativeLanguageName)).

PROGRESSIVE CURRICULUM SEQUENCE:
The user has already successfully completed the following lesson topics/titles in this curriculum: \(completedLessons.isEmpty ? "None yet" : completedLessons.joined(separator: ", ")).
- Study this list of completed lessons. You MUST generate the next logical sequential topic/unit from the textbook curriculum for level \(difficulty).
- If the list is empty, start with the very first unit or lesson of the textbook (e.g., English File Unit 1A, or Hueber Menschen Lektion 1) for the target level.
- Do NOT repeat any topic/unit that has already been completed.
- Make a special emphasis on practical, spoken phrases, patterns, and interactive grammar rules that allow the user to start speaking as quickly as possible. Explain structures that help build conversational speed and fluency.
- LEVEL UPGRADE FLAG: If this generated lesson represents the final unit/chapter of the standard textbook curriculum for level \(difficulty) (e.g. Unit 12 for English File, or Lektion 24 for Menschen), set 'isLevelCompleted' to true, and write a congratulatory 'levelUpgradeMessage' in \(nativeLanguageName) explaining that they are moving to the next level. Otherwise, set 'isLevelCompleted' to false and 'levelUpgradeMessage' to an empty string.
```

When AI Memory is enabled and studied words exist, this is appended:
```
- EXCLUSION CONSTRAINT: The user has already studied the following vocabulary words: \(studiedWords.joined(separator: ", ")). Do NOT use these exact words as the main taught vocabulary items in this lesson.
```

**Expected response** (JSON per schema → decoded into `LanguageLesson`):
```
{
  title: STRING,
  grammarTopic: STRING,
  grammarExplanation: STRING,          // Markdown, in the native language
  conversationText: STRING,            // dialogue in the target language
  conversationTranslation: STRING,     // dialogue translation
  isLevelCompleted: BOOLEAN,           // end-of-level flag
  levelUpgradeMessage: STRING,
  vocabulary: [ { word, translation, phoneticGuide, contextSentence, contextTranslation } ],   // 8–12 items
  exercises:  [ { question, options: [STRING], correctOptionIndex: INTEGER, explanation } ]    // 4–6 items
}
```
All fields are required.

---

## 2. `generateLevelExam` — final level exam

**Triggered by:** opening the exam screen (the banner on the Learn tab after finishing a level's curriculum), and the "Retake Exam" button.

**Variables:** `targetLanguage`, `difficulty` (the level under examination), `nativeLanguageName`, `completedLessons`.

**Prompt:**
```
Act as a strict but fair \(targetLanguage) examiner. Create a final exam for CEFR level \(difficulty) that verifies the student is ready to move to the next level.

The student has completed the following curriculum lessons: \(completedLessons.isEmpty ? "the standard full curriculum for this level" : completedLessons.joined(separator: ", ")).

Requirements:
- Exactly 12 multiple-choice questions.
- Cover the full range of grammar topics and vocabulary of level \(difficulty), with emphasis on the completed lessons listed above.
- Each question has 3 or 4 options written in \(targetLanguage); exactly one option is correct.
- The 'explanation' of each answer must be written in \(nativeLanguageName), explaining the rule and why the other options are wrong.
- Do NOT include any HTML tags. Use plain text only.
```

**Expected response** (JSON per schema → `LevelExam`):
```
{
  questions: [ { question, options: [STRING], correctOptionIndex: INTEGER, explanation } ]   // exactly 12
}
```
The pass mark (80%) is enforced client-side, not in the prompt.

---

## 3. `translateCustomWord` — unfamiliar word translation

**Triggered by:** the "Encountered an unfamiliar word?" card inside an open lesson.

**Variables:** `word` (user input), `targetLanguage`, `nativeLanguageName`.

**Prompt:**
```
Translate the word or phrase '\(word)' from \(targetLanguage) to \(nativeLanguageName).
Provide the phonetic transcription/guide, and a short practical example sentence using this word in \(targetLanguage), along with its native translation in \(nativeLanguageName).

Respond ONLY with a JSON object matching this schema:
{
  "word": "The original word capitalized correctly",
  "translation": "The translation in \(nativeLanguageName)",
  "phoneticGuide": "Phonetic spelling or transcription",
  "contextSentence": "A short simple example sentence using this word in \(targetLanguage)",
  "contextTranslation": "Translation of the example sentence in \(nativeLanguageName)"
}
```

**Expected response** (JSON per schema → `TranslatedWord`): `{ word, translation, phoneticGuide, contextSentence, contextTranslation }` — all STRING, all required. The result is saved as an SRS flashcard immediately.

---

## 4. `generateRandomScenario` — random roleplay scenario

**Triggered by:** picking "🎲 Random AI-generated Scenario" on the Roleplay tab. (The other 4 scenarios are static and make no API call.)

**Variables:** `targetLanguage`, `difficulty`, `nativeLanguageName`.

**Prompt:**
```
Create a creative, realistic roleplay scenario for a person learning \(targetLanguage) at level \(difficulty).
The scenario must be highly practical (e.g., ordering food, resolving a conflict, small talk on the street, meeting a new person, IT standup meeting, asking for directions, negotiating a contract).
The explanation of the roles and the context must be written in the user's native language: \(nativeLanguageName).
The starting line must be written in \(targetLanguage).

Respond ONLY with a JSON object matching this schema:
{
  "title": "A short engaging title of the scenario with an emoji at the end",
  "targetRole": "The role that the AI will play (e.g. 'Barista', 'Stranger on the street', 'Vermieter')",
  "userRole": "The role that the user will play (e.g. 'Customer', 'Lost tourist', 'Student')",
  "contextDescription": "A detailed explanation of what is happening, where, and what the goal is (written in \(nativeLanguageName))",
  "startingLine": "The first phrase spoken by the AI in \(targetLanguage) to start the conversation"
}
```

**Expected response** (JSON per schema → `RoleplayScenario`): `{ title, targetRole, userRole, contextDescription, startingLine }` — all STRING, all required.

---

## 5. `generateChatResponse` — AI reply in a roleplay dialogue

**Triggered by:** every user message in an active roleplay session.

**Variables:** `scenario` (scenario data), `history` (full conversation, flattened line by line as `User (role): text` / `AI (role): text`), `targetLanguage`, `difficulty`.

**Prompt:**
```
You are roleplaying with a student learning \(targetLanguage). The student's CEFR level is \(difficulty).
Strictly adapt your vocabulary and grammar complexity to level \(difficulty): for A1/A2 use short, simple sentences and basic high-frequency words; for B1/B2 use moderately complex natural language; for C1 speak fully naturally.

SCENARIO SETUP:
- Title: \(scenario.title)
- Your Role (AI): \(scenario.targetRole)
- User's Role: \(scenario.userRole)
- Context: \(scenario.contextDescription)

CONVERSATION HISTORY:
\(chatHistoryPrompt)

Please reply to the user's latest statement as your character (\(scenario.targetRole)).
Keep your response short (1-3 sentences maximum), natural, engaging, and grammatically correct for a student learning \(targetLanguage).
Do NOT write any translations. Write ONLY your character's response in \(targetLanguage). Do NOT break character under any circumstances.
```

**Expected response:** free-form text (no schema) — a single in-character reply in the target language, 1–3 sentences. The client only trims surrounding whitespace.

---

## 6. `analyzeConversationErrors` — dialogue error analysis ("AI Tutor")

**Triggered by:** the "Check Mistakes" button in an active roleplay session.

**Variables:** `history` (conversation flattened as `User: text` / `AI: text` lines), `targetLanguage`, `nativeLanguageName`.

**Prompt:**
```
You are a language teacher helping a student learn \(targetLanguage).
Please review the user's statements in the following dialogue history:

DIALOGUE HISTORY:
\(chatHistoryPrompt)

Identify any grammar, vocabulary, spelling, or word order mistakes the user (User) made in their statements in \(targetLanguage).
For each mistake:
1. Point it out.
2. Explain why it is wrong and what the correct rule is.
3. Provide the corrected statement.

Write the feedback and explanations entirely in the user's native language: \(nativeLanguageName). Use clear list items.
If the user made absolutely no mistakes, praise them warmly in \(nativeLanguageName) and tell them their dialogue was excellent and grammatically correct.
```

**Expected response:** free-form text (no schema) — an itemized error breakdown in the native language; rendered as-is in the "AI Tutor Error Analysis" sheet.
