import SwiftUI
import SwiftData
import Combine
import AVFoundation
import Speech

// ==========================================
// MARK: - 1. CONFIGURATION
// ==========================================

/// Global configuration for the SudyAI application.
enum Config {
    /// Gemini API Key. The value lives in Secrets.swift, which is excluded from git —
    /// see Secrets.swift.example in the repository root for setup.
    static let geminiAPIKey = Secrets.geminiAPIKey

    /// Base URL for the Gemini API.
    static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    /// Recommended model for generating lessons and processing prompts.
    static let geminiModel = "gemini-2.5-flash"
}

// ==========================================
// MARK: - 2. SETTINGS & LOCALIZATION ENUMS
// ==========================================

/// Supported native languages for app localization and translation targets.
enum NativeLanguage: String, CaseIterable, Identifiable, Codable {
    case russian = "ru"
    case english = "en"
    case german = "de"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .russian: return "Русский 🇷🇺"
        case .english: return "English 🇬🇧"
        case .german: return "Deutsch 🇩🇪"
        }
    }
}

/// App color scheme preferences.
enum AppColorScheme: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
    
    /// Localized displayName mapping.
    func localizedName(for language: NativeLanguage) -> String {
        switch language {
        case .russian:
            switch self {
            case .system: return "Системная"
            case .light: return "Светлая"
            case .dark: return "Тёмная"
            }
        case .english:
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        case .german:
            switch self {
            case .system: return "System"
            case .light: return "Hell"
            case .dark: return "Dunkel"
            }
        }
    }
    
    /// Maps to SwiftUI ColorScheme option.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Global settings storage powered by `@AppStorage` for persistence across app closures.
class AppSettings: ObservableObject {
    @AppStorage("nativeLanguage") var nativeLanguage: NativeLanguage = .russian
    @AppStorage("colorScheme") var colorScheme: AppColorScheme = .system
    @AppStorage("targetLanguage") var targetLanguage: String = "German"
    
    // Separate difficulties for target languages to learn simultaneously at different levels.
    @AppStorage("englishDifficulty") var englishDifficulty: String = "B1"
    @AppStorage("germanDifficulty") var germanDifficulty: String = "A2"
    
    @AppStorage("dailyGoal") var dailyGoal: Int = 5
    @AppStorage("smartReminders") var smartReminders: Bool = true
    @AppStorage("streakCount") var streakCount: Int = 0
    @AppStorage("aiMemoryMode") var aiMemoryMode: Bool = true

    // Level exams pending after finishing a level's curriculum ("" = none; otherwise the CEFR level to be examined).
    @AppStorage("pendingExamEnglish") var pendingExamEnglish: String = ""
    @AppStorage("pendingExamGerman") var pendingExamGerman: String = ""

    /// Resolves the pending exam level for the currently selected target language.
    var activePendingExam: String {
        get {
            targetLanguage == "English" ? pendingExamEnglish : pendingExamGerman
        }
        set {
            if targetLanguage == "English" {
                pendingExamEnglish = newValue
            } else {
                pendingExamGerman = newValue
            }
        }
    }

    /// Resolves the current target difficulty based on selected learning language.
    var activeDifficulty: String {
        get {
            targetLanguage == "English" ? englishDifficulty : germanDifficulty
        }
        set {
            if targetLanguage == "English" {
                englishDifficulty = newValue
            } else {
                germanDifficulty = newValue
            }
        }
    }
    
    func incrementStreak() {
        streakCount += 1
    }
}

/// Returns the next CEFR level in the A1→C1 progression, or nil when the top level is reached.
func nextCEFRLevel(after current: String) -> String? {
    switch current {
    case "A1": return "A2"
    case "A2": return "B1"
    case "B1": return "B2"
    case "B2": return "C1"
    default: return nil
    }
}

/// Localization mapping dictionary providing translations for the entire interface.
struct L10n {
    enum Key {
        case learnTab
        case reviewTab
        case roleplayTab
        case settingsTab
        case selectTargetPath
        case language
        case level
        case generateLesson
        case curatingLesson
        case readyToStart
        case selectLevelDesc
        case somethingWrong
        case tryAgain
        case grammarInsights
        case realLifeContext
        case interactiveQuiz
        case checkAnswer
        case explanation
        case saveToSRS
        case savedToSRS
        case correct
        case incorrect
        
        case srsSystem
        case srsSubtitle
        case dueReviews
        case totalWords
        case startReview
        
        case aiVoiceRoleplay
        case roleplaySubtitle
        case selectScenario
        case enterRoleplay
        
        case settingsTitle
        case sectionLanguageLearning
        case sectionAppearance
        case sectionFeatures
        
        case nativeLangLabel
        case targetLangLabel
        case defaultLevelLabel
        case appThemeLabel
        
        case dailyGoalLabel
        case dailyGoalSub
        case smartRemindersLabel
        case smartRemindersSub
        case streakTrackerLabel
        case streakTrackerSub
        case aiMemoryLabel
        case aiMemorySub
        
        case words
        case days
        
        case launchTitle
        case launchSubtitle
        case germanLabel
        case englishLabel
        
        // Roleplay specific
        case roleplayTitle
        case activeScenarioTitle
        case aiRoleTitle
        case userRoleTitle
        case textPlaceholder
        case finishSession
        case thinking
        
        // Tutor Specific
        case tutorTitle
        case checkMistakesButton
        case tutorAnalyzing
        
        // Dynamic structured lesson additions
        case grammarTopicLabel
        case dialogueLabel
        case vocabularyLabel
        
        // Custom word adds & sequential additions
        case addCustomWordTitle
        case addCustomWordSub
        case addWordPlaceholder
        case addingWord
        case finishLessonButton
        case lessonCompletedToast
    }
    
    /// Returns the translated string for a specific key and target language.
    static func string(for key: Key, language: NativeLanguage) -> String {
        switch language {
        case .russian:
            switch key {
            case .learnTab: return "Изучение"
            case .reviewTab: return "Повторение"
            case .roleplayTab: return "Говорение"
            case .settingsTab: return "Настройки"
            case .selectTargetPath: return "Направление обучения"
            case .language: return "Язык"
            case .level: return "Уровень"
            case .generateLesson: return "Сгенерировать урок"
            case .curatingLesson: return "Gemini составляет ваш урок..."
            case .readyToStart: return "Готовы начать?"
            case .selectLevelDesc: return "Выберите уровень и изучаемый язык, а затем создайте индивидуальный урок для жизни или работы в Германии."
            case .somethingWrong: return "Что-то пошло не так"
            case .tryAgain: return "Попробовать снова"
            case .grammarInsights: return "Грамматический фокус"
            case .realLifeContext: return "Практический диалог / Текст"
            case .interactiveQuiz: return "Тест по теме урока"
            case .checkAnswer: return "Проверить ответы"
            case .explanation: return "Объяснение:"
            case .saveToSRS: return "Добавить слова в карточки (SRS)"
            case .savedToSRS: return "Слова добавлены в SRS"
            case .correct: return "Правильно!"
            case .incorrect: return "Неверно"
            case .srsSystem: return "Интервальное повторение"
            case .srsSubtitle: return "Закрепляйте слова в долговременной памяти. Алгоритм SM-2 рассчитывает время каждого повторения."
            case .dueReviews: return "К повторению"
            case .totalWords: return "Всего слов"
            case .startReview: return "Начать повторение"
            case .aiVoiceRoleplay: return "Разговорный ИИ"
            case .roleplaySubtitle: return "Имитируйте устное общение в реальных ситуациях. Говорите с ИИ, тренируйте восприятие на слух и произношение."
            case .selectScenario: return "ВЫБЕРИТЕ СЦЕНАРИЙ"
            case .enterRoleplay: return "Начать диалог с ИИ"
            case .settingsTitle: return "Настройки"
            case .sectionLanguageLearning: return "Язык и Обучение"
            case .sectionAppearance: return "Внешний вид"
            case .sectionFeatures: return "Интересные функции"
            case .nativeLangLabel: return "Родной язык"
            case .targetLangLabel: return "Изучаемый язык"
            case .defaultLevelLabel: return "Уровень сложности"
            case .appThemeLabel: return "Тема оформления"
            case .dailyGoalLabel: return "Цель на день"
            case .dailyGoalSub: return "Количество новых слов в день"
            case .smartRemindersLabel: return "Напоминания"
            case .smartRemindersSub: return "Умные уведомления о повторении"
            case .streakTrackerLabel: return "Серия занятий"
            case .streakTrackerSub: return "Дней занятий подряд"
            case .aiMemoryLabel: return "Память ИИ"
            case .aiMemorySub: return "ИИ помнит изученное и не генерирует повторы"
            case .words: return "слов"
            case .days: return "дн."
            case .launchTitle: return "Что учим сегодня?"
            case .launchSubtitle: return "Выберите язык для текущей сессии изучения"
            case .germanLabel: return "🇩🇪 Deutsch (Немецкий)"
            case .englishLabel: return "🇬🇧 English (Английский)"
            case .roleplayTitle: return "Интерактивный диалог"
            case .activeScenarioTitle: return "Текущий сценарий"
            case .aiRoleTitle: return "Роль ИИ"
            case .userRoleTitle: return "Ваша роль"
            case .textPlaceholder: return "Введите ваш ответ..."
            case .finishSession: return "Завершить сессию"
            case .thinking: return "ИИ думает..."
            case .tutorTitle: return "Разбор ошибок от AI Tutor"
            case .checkMistakesButton: return "Проверить ошибки"
            case .tutorAnalyzing: return "Анализируем ваш диалог..."
            case .grammarTopicLabel: return "ТЕМА УРОКА"
            case .dialogueLabel: return "ДИАЛОГ / ЧТЕНИЕ"
            case .vocabularyLabel: return "ЛЕКСИКА УРОКА"
            case .addCustomWordTitle: return "Встретили незнакомое слово в уроке?"
            case .addCustomWordSub: return "Введите его ниже. ИИ мгновенно переведет его, подберет правильную транскрипцию, пример и сохранит в ваши карточки повторения."
            case .addWordPlaceholder: return "Например: deadline, anmeldung..."
            case .addingWord: return "ИИ переводит и сохраняет..."
            case .finishLessonButton: return "Завершить и отметить как пройденный"
            case .lessonCompletedToast: return "Отлично! Урок отмечен как пройденный. Следующий урок будет автоматически выбран по программе дальше."
            }
            
        case .english:
            switch key {
            case .learnTab: return "Learn"
            case .reviewTab: return "Review"
            case .roleplayTab: return "Roleplay"
            case .settingsTab: return "Settings"
            case .selectTargetPath: return "Select Target Path"
            case .language: return "Language"
            case .level: return "Level"
            case .generateLesson: return "Generate Custom Lesson"
            case .curatingLesson: return "Gemini is curating your vocabulary lesson..."
            case .readyToStart: return "Ready to Start?"
            case .selectLevelDesc: return "Select your level and language, then request a lesson tailored for your relocation to Germany."
            case .somethingWrong: return "Something went wrong"
            case .tryAgain: return "Try Again"
            case .grammarInsights: return "Grammar Focus"
            case .realLifeContext: return "Practical Dialogue / Reading"
            case .interactiveQuiz: return "Lesson Topic Quiz"
            case .checkAnswer: return "Check Answers"
            case .explanation: return "Explanation:"
            case .saveToSRS: return "Add Words to SRS Cards"
            case .savedToSRS: return "Words Saved to SRS"
            case .correct: return "Correct!"
            case .incorrect: return "Incorrect"
            case .srsSystem: return "Spaced Repetition System"
            case .srsSubtitle: return "Lock your vocabulary into long-term memory. The SuperMemo SM-2 algorithm handles the intervals."
            case .dueReviews: return "Due Reviews"
            case .totalWords: return "Total Words"
            case .startReview: return "Start Review Session"
            case .aiVoiceRoleplay: return "AI Voice Roleplay"
            case .roleplaySubtitle: return "Simulate spoken roleplays in real scenarios. Speak to the AI, and practice listening and pronunciation."
            case .selectScenario: return "SELECT SCENARIO"
            case .enterRoleplay: return "Enter Roleplay Session"
            case .settingsTitle: return "Settings"
            case .sectionLanguageLearning: return "Language & Learning"
            case .sectionAppearance: return "Appearance"
            case .sectionFeatures: return "Special Features"
            case .nativeLangLabel: return "Native Language"
            case .targetLangLabel: return "Target Language"
            case .defaultLevelLabel: return "Difficulty Level"
            case .appThemeLabel: return "App Theme"
            case .dailyGoalLabel: return "Daily Goal"
            case .dailyGoalSub: return "Desired number of new words daily"
            case .smartRemindersLabel: return "Smart Reminders"
            case .smartRemindersSub: return "Get smart alerts to review vocabulary"
            case .streakTrackerLabel: return "Streak Tracker"
            case .streakTrackerSub: return "Consecutive days of studying"
            case .aiMemoryLabel: return "AI Memory Mode"
            case .aiMemorySub: return "AI will remember studied cards to prevent repeats"
            case .words: return "words"
            case .days: return "days"
            case .launchTitle: return "What are we learning today?"
            case .launchSubtitle: return "Select target language for the current session"
            case .germanLabel: return "🇩🇪 German (Deutsch)"
            case .englishLabel: return "🇬🇧 English (English)"
            case .roleplayTitle: return "Interactive Roleplay"
            case .activeScenarioTitle: return "Active Scenario"
            case .aiRoleTitle: return "AI Role"
            case .userRoleTitle: return "Your Role"
            case .textPlaceholder: return "Type your response..."
            case .finishSession: return "Finish Session"
            case .thinking: return "AI is typing..."
            case .tutorTitle: return "AI Tutor Error Analysis"
            case .checkMistakesButton: return "Check Mistakes"
            case .tutorAnalyzing: return "Analyzing your dialogue..."
            case .grammarTopicLabel: return "LESSON TOPIC"
            case .dialogueLabel: return "DIALOGUE / READING"
            case .vocabularyLabel: return "LESSON VOCABULARY"
            case .addCustomWordTitle: return "Encountered an unfamiliar word?"
            case .addCustomWordSub: return "Type the word below. The AI will translate it, add phonetic transcriptions, format an example, and save it directly into your review stack."
            case .addWordPlaceholder: return "Example: deadline, anmeldung..."
            case .addingWord: return "AI is translating and saving..."
            case .finishLessonButton: return "Mark Lesson as Completed"
            case .lessonCompletedToast: return "Great! Lesson completed. The next lesson generated will proceed further along the sequential curriculum."
            }
            
        case .german:
            switch key {
            case .learnTab: return "Lernen"
            case .reviewTab: return "Wiederholen"
            case .roleplayTab: return "Rollenspiel"
            case .settingsTab: return "Einstellungen"
            case .selectTargetPath: return "Zielpfad auswählen"
            case .language: return "Sprache"
            case .level: return "Niveau"
            case .generateLesson: return "Lektion generieren"
            case .curatingLesson: return "Gemini erstellt deine Lektion..."
            case .readyToStart: return "Bereit anzufangen?"
            case .selectLevelDesc: return "Wähle dein Niveau und deine Zielsprache aus und fordere eine Lektion an, die auf deinen Umzug nach Deutschland zugeschnitten ist."
            case .somethingWrong: return "Etwas ist schief gelaufen"
            case .tryAgain: return "Erneut versuchen"
            case .grammarInsights: return "Grammatikfokus"
            case .realLifeContext: return "Praktischer Dialog / Text"
            case .interactiveQuiz: return "Lektionsthemen-Quiz"
            case .checkAnswer: return "Antworten prüfen"
            case .explanation: return "Erklärung:"
            case .saveToSRS: return "Wörter in SRS-Karten speichern"
            case .savedToSRS: return "In SRS gespeichert"
            case .correct: return "Richtig!"
            case .incorrect: return "Falsch"
            case .srsSystem: return "Spaced Repetition System"
            case .srsSubtitle: return "Präge dir Vokabeln im Langzeitgedächtnis ein. Der SuperMemo SM-2 Algorithmus steuert die Intervalle."
            case .dueReviews: return "Fällige Karten"
            case .totalWords: return "Wörter insgesamt"
            case .startReview: return "Wiederholung starten"
            case .aiVoiceRoleplay: return "KI-Rollenspiel"
            case .roleplaySubtitle: return "Simuliere gesprochene Rollenspiele in realen Szenarien. Sprich mit der KI und übe Hören und Aussprache."
            case .selectScenario: return "SZENARIO WÄHLEN"
            case .enterRoleplay: return "Rollenspiel starten"
            case .settingsTitle: return "Einstellungen"
            case .sectionLanguageLearning: return "Sprache & Lernen"
            case .sectionAppearance: return "Aussehen"
            case .sectionFeatures: return "Spezielle Funktionen"
            case .nativeLangLabel: return "Muttersprache"
            case .targetLangLabel: return "Zielsprache"
            case .defaultLevelLabel: return "Schwierigkeitsgrad"
            case .appThemeLabel: return "App-Design"
            case .dailyGoalLabel: return "Tagesziel"
            case .dailyGoalSub: return "Gewünschte ANzahl neuer Wörter pro Tag"
            case .smartRemindersLabel: return "Intelligente Erinnerungen"
            case .smartRemindersSub: return "Erhalte intelligente Erinnerungen zur Wiederholung"
            case .streakTrackerLabel: return "Lernserie"
            case .streakTrackerSub: return "Aufeinanderfolgende Studientage"
            case .aiMemoryLabel: return "KI-Gedächmisse-Modus"
            case .aiMemorySub: return "KI merkt sich gelernte Karten, um Wiederholungen zu vermeiden"
            case .words: return "Wörter"
            case .days: return "Tage"
            case .launchTitle: return "Was lernen wir heute?"
            case .launchSubtitle: return "Wähle die Zielsprache für diese Lerneinheit"
            case .germanLabel: return "🇩🇪 German (Deutsch)"
            case .englishLabel: return "🇬🇧 Englisch (English)"
            case .roleplayTitle: return "Interaktives Rollenspiel"
            case .activeScenarioTitle: return "Aktives Szenario"
            case .aiRoleTitle: return "KI-Rolle"
            case .userRoleTitle: return "Deine Rolle"
            case .textPlaceholder: return "Schreibe deine Antwort..."
            case .finishSession: return "Sitzung beenden"
            case .thinking: return "KI antwortet..."
            case .tutorTitle: return "AI Tutor Fehleranalyse"
            case .checkMistakesButton: return "Fehler prüfen"
            case .tutorAnalyzing: return "Analysiere deinen Dialog..."
            case .grammarTopicLabel: return "LEKTIONSTHEMA"
            case .dialogueLabel: return "DIALOG / LESEN"
            case .vocabularyLabel: return "LEKTIONSVOKABELN"
            case .addCustomWordTitle: return "Unbekanntes Wort gefunden?"
            case .addCustomWordSub: return "Schreibe das Wort unten auf. Die KI übersetzt es, findet die Lautschrift, erstellt ein Beispiel und speichert es in deinen Lernkarten."
            case .addWordPlaceholder: return "z.B. deadline, anmeldung..."
            case .addingWord: return "KI übersetzt und speichert..."
            case .finishLessonButton: return "Lektion abschließen und speichern"
            case .lessonCompletedToast: return "Lektion abgeschlossen! Die nächste Lektion wird in der Reihenfolge fortgesetzt."
            }
        }
    }
}

// ==========================================
// MARK: - 3. SWIFTDATA MODELS
// ==========================================

/// A SwiftData model representing a vocabulary item in the user's database.
/// Includes parameters and logic for scheduling reviews using the SuperMemo SM-2 SRS algorithm.
@Model
final class VocabCard {
    @Attribute(.unique) var id: UUID
    var word: String
    var translation: String
    var targetLanguage: String
    var difficulty: String
    var contextSentence: String
    var contextTranslation: String
    var grammarNotes: String
    
    // MARK: - SRS Parameters
    var srsInterval: Int
    var srsEaseFactor: Double
    var srsRepetitions: Int
    var nextReviewDate: Date
    var createdAt: Date
    
    init(id: UUID = UUID(),
         word: String,
         translation: String,
         targetLanguage: String,
         difficulty: String,
         contextSentence: String,
         contextTranslation: String,
         grammarNotes: String,
         srsInterval: Int = 1,
         srsEaseFactor: Double = 2.5,
         srsRepetitions: Int = 0,
         nextReviewDate: Date = Date(),
         createdAt: Date = Date()) {
        self.id = id
        self.word = word
        self.translation = translation
        self.targetLanguage = targetLanguage
        self.difficulty = difficulty
        self.contextSentence = contextSentence
        self.contextTranslation = contextTranslation
        self.grammarNotes = grammarNotes
        self.srsInterval = srsInterval
        self.srsEaseFactor = srsEaseFactor
        self.srsRepetitions = srsRepetitions
        self.nextReviewDate = nextReviewDate
        self.createdAt = createdAt
    }
    
    /// Updates the spaced repetition metadata using the SuperMemo SM-2 algorithm.
    func updateSRSProgress(qualityScore: Int) {
        let q = max(0, min(5, qualityScore))
        
        if q >= 3 {
            // Correct response
            if srsRepetitions == 0 {
                srsInterval = 1
            } else if srsRepetitions == 1 {
                srsInterval = 6
            } else {
                srsInterval = Int(round(Double(srsInterval) * srsEaseFactor))
            }
            srsRepetitions += 1
        } else {
            // Incorrect response
            srsRepetitions = 0
            srsInterval = 1
        }
        
        // Calculate new ease factor: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        let diff = 5.0 - Double(q)
        let deltaEase = 0.1 - diff * (0.08 + diff * 0.02)
        srsEaseFactor = max(1.3, srsEaseFactor + deltaEase)
        
        // Calculate the next review date by adding the interval in days to the current date
        nextReviewDate = Calendar.current.date(byAdding: .day, value: srsInterval, to: Date()) ?? Date()
    }
}

/// A SwiftData model storing the titles of completed course lessons to enable progressive learning paths.
@Model
final class StudiedLesson {
    @Attribute(.unique) var id: String
    var targetLanguage: String
    var difficulty: String
    var completedAt: Date
    
    init(id: String, targetLanguage: String, difficulty: String, completedAt: Date = Date()) {
        self.id = id
        self.targetLanguage = targetLanguage
        self.difficulty = difficulty
        self.completedAt = completedAt
    }
}

/// A SwiftData model persisting full generated lessons so they survive app restarts and can be reopened.
@Model
final class SavedLesson {
    @Attribute(.unique) var title: String
    var targetLanguage: String
    var difficulty: String
    var lessonData: Data
    var isCompleted: Bool
    var createdAt: Date

    init(title: String, targetLanguage: String, difficulty: String, lessonData: Data, isCompleted: Bool = false, createdAt: Date = Date()) {
        self.title = title
        self.targetLanguage = targetLanguage
        self.difficulty = difficulty
        self.lessonData = lessonData
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    /// Decodes the stored lesson payload.
    var lesson: LanguageLesson? {
        try? JSONDecoder().decode(LanguageLesson.self, from: lessonData)
    }
}

// ==========================================
// MARK: - 4. STRUCTS FOR DTOs & SCENARIOS
// ==========================================

/// Represents a dynamic structured lesson generated by the Gemini AI.
struct LanguageLesson: Codable, Identifiable, Equatable {
    var id: String { title }
    
    let title: String
    let grammarTopic: String
    let grammarExplanation: String
    let conversationText: String
    let conversationTranslation: String
    let vocabulary: [LessonVocabulary]
    let exercises: [PracticeExercise]
    
    // Level progression parameters
    let isLevelCompleted: Bool
    let levelUpgradeMessage: String
}

/// Represents one vocabulary word taught inside a structured lesson.
struct LessonVocabulary: Codable, Hashable {
    let word: String
    let translation: String
    let phoneticGuide: String
    let contextSentence: String
    let contextTranslation: String
}

/// A multiple-choice practice exercise designed by the AI.
struct PracticeExercise: Codable, Equatable {
    let question: String
    let options: [String]
    let correctOptionIndex: Int
    let explanation: String
}

/// A final exam for a CEFR level, generated when the level's curriculum is finished. Passing it unlocks the next level.
struct LevelExam: Codable {
    let questions: [PracticeExercise]
}

/// A roleplaying context generated by the AI or premade.
struct RoleplayScenario: Codable, Equatable {
    let title: String
    let targetRole: String
    let userRole: String
    let contextDescription: String
    let startingLine: String
}

/// Represents a custom word translated and analyzed by the AI.
struct TranslatedWord: Codable {
    let word: String
    let translation: String
    let phoneticGuide: String
    let contextSentence: String
    let contextTranslation: String
}

// ==========================================
// MARK: - 5. SPEECH (TTS) MANAGER
// ==========================================

/// Speech Manager executing local Text-To-Speech audio synthesis using `AVSpeechSynthesizer`.
class SpeechManager {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    /// Speaks a given text with specified locale language code.
    func speak(_ text: String, languageCode: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        
        synthesizer.speak(utterance)
    }
}

// ==========================================
// MARK: - 6. SPEECH RECOGNITION (STT) MANAGER
// ==========================================

/// Handles microphone access and captures realtime spoken voice transcripts using Apple's `Speech` framework.
class SpeechRecognizerManager: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// Requests speech and microphone permissions.
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
    
    /// Starts capturing speech from the mic and updates the published `transcript` property in real-time.
    func startRecording(languageCode: String) {
        stopRecording()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Speech audio session initialization failed: \(error.localizedDescription)")
            return
        }
        
        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let audioEngine = audioEngine,
              let recognitionRequest = recognitionRequest,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageCode)),
              recognizer.isAvailable else {
            print("Speech recognizer is not available for locale: \(languageCode)")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Remove existing tap if necessary
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            withAnimation { self.isRecording = true }
        } catch {
            print("Audio engine start failed: \(error.localizedDescription)")
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
    }
    
    /// Stops recording audio and releases resources.
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        DispatchQueue.main.async {
            withAnimation { self.isRecording = false }
        }
    }
}

// ==========================================
// MARK: - 7. NETWORKING SERVICES
// ==========================================

/// Service responsible for communicating with the Gemini API.
class GeminiService {
    
    enum GeminiError: Error, LocalizedError {
        case invalidURL
        case noData
        case decodingError(Error)
        case apiError(String)
        case schemaValidationError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "The API URL is invalid."
            case .noData: return "No data received from the Gemini server."
            case .decodingError(let error): return "Failed to parse the lesson JSON: \(error.localizedDescription)"
            case .apiError(let message): return "Gemini API error: \(message)"
            case .schemaValidationError: return "The response schema is invalid or incomplete."
            }
        }
    }
    
    /// Generates a structured course lesson based on target language standards.
    /// Incorporates English File (for English) or Hueber (for German) and sequential curriculum checking.
    func generateLesson(targetLanguage: String, difficulty: String, nativeLanguageName: String, studiedWords: [String], completedLessons: [String]) async throws -> LanguageLesson {
        guard !Config.geminiAPIKey.isEmpty else {
            throw GeminiError.apiError("Gemini API key is empty. Please set your API key in Config.swift.")
        }
        
        let urlString = "\(Config.geminiBaseURL)/\(Config.geminiModel):generateContent?key=\(Config.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        var curriculumInstruction = ""
        if targetLanguage == "English" {
            curriculumInstruction = "Act as an expert English teacher following the curriculum structure of the book 'English File (Fifth Edition) — Oxford University Press' for CEFR level \(difficulty)."
        } else {
            curriculumInstruction = "Act as an expert German teacher following the curriculum structure of the textbook series published by 'Hueber Verlag' (e.g. Menschen, Schritte, or Sicher) for CEFR level \(difficulty)."
        }
        
        var prompt = """
        \(curriculumInstruction)
        
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
        - For lists, points, or formatting in the grammar explanation, use only standard Markdown (e.g. asterisks '*' or hyphens '-' for bullet points, double asterisks for bolding, and newlines '\\n').
        - All translations, explanations of grammar, and explanations of quiz answers must be written in the user's native language (\(nativeLanguageName)).
        
        PROGRESSIVE CURRICULUM SEQUENCE:
        The user has already successfully completed the following lesson topics/titles in this curriculum: \(completedLessons.isEmpty ? "None yet" : completedLessons.joined(separator: ", ")).
        - Study this list of completed lessons. You MUST generate the next logical sequential topic/unit from the textbook curriculum for level \(difficulty).
        - If the list is empty, start with the very first unit or lesson of the textbook (e.g., English File Unit 1A, or Hueber Menschen Lektion 1) for the target level.
        - Do NOT repeat any topic/unit that has already been completed.
        - Make a special emphasis on practical, spoken phrases, patterns, and interactive grammar rules that allow the user to start speaking as quickly as possible. Explain structures that help build conversational speed and fluency.
        - LEVEL UPGRADE FLAG: If this generated lesson represents the final unit/chapter of the standard textbook curriculum for level \(difficulty) (e.g. Unit 12 for English File, or Lektion 24 for Menschen), set 'isLevelCompleted' to true, and write a congratulatory 'levelUpgradeMessage' in \(nativeLanguageName) explaining that they are moving to the next level. Otherwise, set 'isLevelCompleted' to false and 'levelUpgradeMessage' to an empty string.
        """
        
        // Adaptive Memory Constraint
        if !studiedWords.isEmpty {
            prompt += "\n- EXCLUSION CONSTRAINT: The user has already studied the following vocabulary words: \(studiedWords.joined(separator: ", ")). Do NOT use these exact words as the main taught vocabulary items in this lesson."
        }
        
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "title": ["type": "STRING"],
                "grammarTopic": ["type": "STRING"],
                "grammarExplanation": ["type": "STRING"],
                "conversationText": ["type": "STRING"],
                "conversationTranslation": ["type": "STRING"],
                "isLevelCompleted": ["type": "BOOLEAN"],
                "levelUpgradeMessage": ["type": "STRING"],
                "vocabulary": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "word": ["type": "STRING"],
                            "translation": ["type": "STRING"],
                            "phoneticGuide": ["type": "STRING"],
                            "contextSentence": ["type": "STRING"],
                            "contextTranslation": ["type": "STRING"]
                        ],
                        "required": ["word", "translation", "phoneticGuide", "contextSentence", "contextTranslation"]
                    ]
                ],
                "exercises": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "question": ["type": "STRING"],
                            "options": [
                                "type": "ARRAY",
                                "items": ["type": "STRING"]
                            ],
                            "correctOptionIndex": ["type": "INTEGER"],
                            "explanation": ["type": "STRING"]
                        ],
                        "required": ["question", "options", "correctOptionIndex", "explanation"]
                    ]
                ]
            ],
            "required": ["title", "grammarTopic", "grammarExplanation", "conversationText", "conversationTranslation", "vocabulary", "exercises", "isLevelCompleted", "levelUpgradeMessage"]
        ]
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.apiError("Invalid HTTP response.")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("HTTP status code \(httpResponse.statusCode)")
        }
        
        let apiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        guard let firstCandidate = apiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first,
              let lessonData = firstPart.text.data(using: .utf8) else {
            throw GeminiError.schemaValidationError
        }
        
        do {
            let decoder = JSONDecoder()
            let lesson = try decoder.decode(LanguageLesson.self, from: lessonData)
            return lesson
        } catch {
            throw GeminiError.decodingError(error)
        }
    }

    /// Generates a final level exam covering the whole CEFR level curriculum. Passing it unlocks the next level.
    func generateLevelExam(targetLanguage: String, difficulty: String, nativeLanguageName: String, completedLessons: [String]) async throws -> LevelExam {
        guard !Config.geminiAPIKey.isEmpty else {
            throw GeminiError.apiError("Gemini API key is empty.")
        }

        let urlString = "\(Config.geminiBaseURL)/\(Config.geminiModel):generateContent?key=\(Config.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }

        let prompt = """
        Act as a strict but fair \(targetLanguage) examiner. Create a final exam for CEFR level \(difficulty) that verifies the student is ready to move to the next level.

        The student has completed the following curriculum lessons: \(completedLessons.isEmpty ? "the standard full curriculum for this level" : completedLessons.joined(separator: ", ")).

        Requirements:
        - Exactly 12 multiple-choice questions.
        - Cover the full range of grammar topics and vocabulary of level \(difficulty), with emphasis on the completed lessons listed above.
        - Each question has 3 or 4 options written in \(targetLanguage); exactly one option is correct.
        - The 'explanation' of each answer must be written in \(nativeLanguageName), explaining the rule and why the other options are wrong.
        - Do NOT include any HTML tags. Use plain text only.
        """

        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "questions": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "question": ["type": "STRING"],
                            "options": [
                                "type": "ARRAY",
                                "items": ["type": "STRING"]
                            ],
                            "correctOptionIndex": ["type": "INTEGER"],
                            "explanation": ["type": "STRING"]
                        ],
                        "required": ["question", "options", "correctOptionIndex", "explanation"]
                    ]
                ]
            ],
            "required": ["questions"]
        ]

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.apiError("Exam generation request failed.")
        }

        let apiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        guard let firstCandidate = apiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first,
              let examData = firstPart.text.data(using: .utf8) else {
            throw GeminiError.schemaValidationError
        }

        return try JSONDecoder().decode(LevelExam.self, from: examData)
    }

    /// Translates a single unfamiliar word entered by the user, providing transcription, example, and meaning.
    func translateCustomWord(word: String, targetLanguage: String, nativeLanguageName: String) async throws -> TranslatedWord {
        guard !Config.geminiAPIKey.isEmpty else {
            throw GeminiError.apiError("Gemini API key is empty.")
        }
        
        let urlString = "\(Config.geminiBaseURL)/\(Config.geminiModel):generateContent?key=\(Config.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        let prompt = """
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
        """
        
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "word": ["type": "STRING"],
                "translation": ["type": "STRING"],
                "phoneticGuide": ["type": "STRING"],
                "contextSentence": ["type": "STRING"],
                "contextTranslation": ["type": "STRING"]
            ],
            "required": ["word", "translation", "phoneticGuide", "contextSentence", "contextTranslation"]
        ]
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.apiError("Translation request failed.")
        }
        
        let apiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        guard let firstCandidate = apiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first,
              let wordData = firstPart.text.data(using: .utf8) else {
            throw GeminiError.schemaValidationError
        }
        
        return try JSONDecoder().decode(TranslatedWord.self, from: wordData)
    }
    
    /// Requests a dynamic, fully simulated context scenario for roleplaying dialogues.
    func generateRandomScenario(targetLanguage: String, difficulty: String, nativeLanguageName: String) async throws -> RoleplayScenario {
        guard !Config.geminiAPIKey.isEmpty else {
            throw GeminiError.apiError("Gemini API key is empty.")
        }
        
        let urlString = "\(Config.geminiBaseURL)/\(Config.geminiModel):generateContent?key=\(Config.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        let prompt = """
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
        """
        
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "title": ["type": "STRING"],
                "targetRole": ["type": "STRING"],
                "userRole": ["type": "STRING"],
                "contextDescription": ["type": "STRING"],
                "startingLine": ["type": "STRING"]
            ],
            "required": ["title", "targetRole", "userRole", "contextDescription", "startingLine"]
        ]
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.apiError("API call failed")
        }
        
        let apiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        guard let firstCandidate = apiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first,
              let lessonData = firstPart.text.data(using: .utf8) else {
            throw GeminiError.schemaValidationError
        }
        
        return try JSONDecoder().decode(RoleplayScenario.self, from: lessonData)
    }
    
    /// Replies to the user's latest statement inside a roleplaying dialog session.
    func generateChatResponse(scenario: RoleplayScenario, history: [RoleplayViewModel.Message], targetLanguage: String, difficulty: String) async throws -> String {
        guard !Config.geminiAPIKey.isEmpty else {
            throw GeminiError.apiError("Gemini API key is empty.")
        }
        
        let urlString = "\(Config.geminiBaseURL)/\(Config.geminiModel):generateContent?key=\(Config.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        var chatHistoryPrompt = ""
        for msg in history {
            chatHistoryPrompt += "\(msg.isUser ? "User (\(scenario.userRole))" : "AI (\(scenario.targetRole))"): \(msg.text)\n"
        }
        
        let prompt = """
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
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.apiError("API call failed")
        }
        
        let apiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        guard let firstCandidate = apiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first else {
            throw GeminiError.schemaValidationError
        }
        
        return firstPart.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Requests a grammatical and syntax audit of the user's roleplay conversation logs.
    func analyzeConversationErrors(scenario: RoleplayScenario, history: [RoleplayViewModel.Message], targetLanguage: String, nativeLanguageName: String) async throws -> String {
        guard !Config.geminiAPIKey.isEmpty else {
            throw GeminiError.apiError("Gemini API key is empty.")
        }
        
        let urlString = "\(Config.geminiBaseURL)/\(Config.geminiModel):generateContent?key=\(Config.geminiAPIKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        var chatHistoryPrompt = ""
        for msg in history {
            chatHistoryPrompt += "\(msg.isUser ? "User" : "AI"): \(msg.text)\n"
        }
        
        let prompt = """
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
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GeminiError.apiError("API call failed")
        }
        
        let apiResponse = try JSONDecoder().decode(GeminiAPIResponse.self, from: data)
        guard let firstCandidate = apiResponse.candidates.first,
              let firstPart = firstCandidate.content.parts.first else {
            throw GeminiError.schemaValidationError
        }
        
        return firstPart.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

fileprivate struct GeminiAPIResponse: Decodable {
    let candidates: [Candidate]
    
    struct Candidate: Decodable {
        let content: Content
    }
    
    struct Content: Decodable {
        let parts: [Part]
    }
    
    struct Part: Decodable {
        let text: String
    }
}

// ==========================================
// MARK: - 8. VIEWMODELS
// ==========================================

/// View Model for the Learn tab, managing the state, API calls, and local storage integration.
@MainActor
class LearnViewModel: ObservableObject {
    
    enum State: Equatable {
        case idle
        case loading
        case loaded(LanguageLesson)
        case error(String)
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.loading, .loading): return true
            case (.loaded(let l1), .loaded(let l2)): return l1 == l2
            case (.error(let e1), .error(let e2)): return e1 == e2
            default: return false
            }
        }
    }
    
    @Published var state: State = .idle
    @Published var isSaved: Bool = false
    @Published var isCompleted: Bool = false
    @Published var showUpgradeAlert = false
    @Published var upgradeMessageText = ""
    
    // Quiz states for multiple exercises inside the new structured lesson
    @Published var selectedOptions: [Int: Int] = [:] // Maps exercise index to selected option index
    @Published var quizChecked: Bool = false
    
    // Unfamiliar custom word translator states
    @Published var customWordInput = ""
    @Published var isTranslatingCustomWord = false
    @Published var customWordFeedbackMessage = ""
    
    private let geminiService = GeminiService()
    
    /// Fetches a dynamic lesson, translating elements using the selected native language name.
    /// Incorporates the studied database words to support adaptive learning memory.
    func fetchLesson(context: ModelContext, targetLanguage: String, difficulty: String, nativeLanguage: NativeLanguage, studiedWords: [String], completedLessons: [String]) {
        state = .loading
        isSaved = false
        isCompleted = false
        selectedOptions = [:]
        quizChecked = false
        customWordInput = ""
        customWordFeedbackMessage = ""
        
        Task {
            do {
                let nativeLangName = nativeLanguageName(for: nativeLanguage)
                let lesson = try await geminiService.generateLesson(
                    targetLanguage: targetLanguage,
                    difficulty: difficulty,
                    nativeLanguageName: nativeLangName,
                    studiedWords: studiedWords,
                    completedLessons: completedLessons
                )
                self.persistLesson(lesson, context: context, targetLanguage: targetLanguage, difficulty: difficulty)
                self.state = .loaded(lesson)
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }
    
    private func nativeLanguageName(for lang: NativeLanguage) -> String {
        switch lang {
        case .russian: return "Russian"
        case .english: return "English"
        case .german: return "German"
        }
    }
    
    // MARK: - Quiz scoring & completion gating

    /// Number of quiz questions the user answered correctly.
    func correctAnswersCount(in exercises: [PracticeExercise]) -> Int {
        exercises.enumerated().reduce(0) { acc, pair in
            acc + (selectedOptions[pair.offset] == pair.element.correctOptionIndex ? 1 : 0)
        }
    }

    /// The lesson can only be completed when at least 70% of quiz answers are correct.
    func isQuizPassed(exercises: [PracticeExercise]) -> Bool {
        guard !exercises.isEmpty else { return true }
        return Double(correctAnswersCount(in: exercises)) / Double(exercises.count) >= 0.7
    }

    func retryQuiz() {
        selectedOptions = [:]
        quizChecked = false
    }

    // MARK: - Lesson persistence

    /// Saves (or refreshes) a generated lesson in SwiftData so it survives app restarts.
    private func persistLesson(_ lesson: LanguageLesson, context: ModelContext, targetLanguage: String, difficulty: String) {
        guard let data = try? JSONEncoder().encode(lesson) else { return }
        let title = lesson.title
        let descriptor = FetchDescriptor<SavedLesson>(predicate: #Predicate { $0.title == title })

        if let existing = try? context.fetch(descriptor).first {
            existing.lessonData = data
            existing.difficulty = difficulty
            existing.createdAt = Date()
        } else {
            context.insert(SavedLesson(title: title, targetLanguage: targetLanguage, difficulty: difficulty, lessonData: data))
        }
        try? context.save()
    }

    /// Reopens a lesson stored in SwiftData.
    func loadSavedLesson(_ saved: SavedLesson) {
        guard let lesson = saved.lesson else { return }
        state = .loaded(lesson)
        isSaved = false
        isCompleted = saved.isCompleted
        selectedOptions = [:]
        quizChecked = false
        customWordInput = ""
        customWordFeedbackMessage = ""
    }

    func saveToSRS(context: ModelContext, targetLanguage: String, difficulty: String) {
        guard case .loaded(let lesson) = state else { return }
        
        do {
            for item in lesson.vocabulary {
                let targetWord = item.word.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let fetchDescriptor = FetchDescriptor<VocabCard>(
                    predicate: #Predicate { card in
                        card.word == targetWord && card.targetLanguage == targetLanguage
                    }
                )
                
                let existingCards = try context.fetch(fetchDescriptor)
                
                if existingCards.isEmpty {
                    let newCard = VocabCard(
                        word: targetWord,
                        translation: item.translation,
                        targetLanguage: targetLanguage,
                        difficulty: difficulty,
                        contextSentence: item.contextSentence,
                        contextTranslation: item.contextTranslation,
                        grammarNotes: lesson.grammarExplanation
                    )
                    context.insert(newCard)
                }
            }
            
            try context.save()
            withAnimation {
                self.isSaved = true
            }
        } catch {
            print("Failed to save vocabulary cards: \(error.localizedDescription)")
        }
    }
    
    func markLessonAsCompleted(context: ModelContext, lesson: LanguageLesson, targetLanguage: String, settings: AppSettings) {
        // The UI disables the button until the quiz is passed; this guard is a safety net.
        guard quizChecked, isQuizPassed(exercises: lesson.exercises) else { return }

        // Lesson vocabulary goes to SRS automatically on completion.
        saveToSRS(context: context, targetLanguage: targetLanguage, difficulty: settings.activeDifficulty)

        let lessonId = lesson.title
        let existingCompleted = try? context.fetch(FetchDescriptor<StudiedLesson>(predicate: #Predicate { $0.id == lessonId })).first
        if existingCompleted == nil {
            context.insert(StudiedLesson(id: lessonId, targetLanguage: targetLanguage, difficulty: settings.activeDifficulty))
        }

        if let saved = try? context.fetch(FetchDescriptor<SavedLesson>(predicate: #Predicate { $0.title == lessonId })).first {
            saved.isCompleted = true
        }

        do {
            try context.save()
            withAnimation {
                self.isCompleted = true
            }

            if lesson.isLevelCompleted {
                // The curriculum is finished, but the next level must be earned by passing the final exam.
                settings.objectWillChange.send()
                settings.activePendingExam = settings.activeDifficulty
                self.upgradeMessageText = settings.nativeLanguage == .russian
                    ? "Программа уровня \(settings.activeDifficulty) пройдена! Теперь сдайте выпускной экзамен (оранжевая кнопка вверху вкладки «Изучение»), чтобы перейти на следующий уровень."
                    : "You have finished the \(settings.activeDifficulty) curriculum! Now pass the final exam (orange button at the top of the Learn tab) to unlock the next level."
                self.showUpgradeAlert = true
            }
        } catch {
            print("Failed to mark lesson completed: \(error.localizedDescription)")
        }
    }
    
    func translateAndAddCustomWord(context: ModelContext, targetLanguage: String, difficulty: String, nativeLanguage: NativeLanguage) {
        let trimmedWord = customWordInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }
        
        customWordInput = ""
        isTranslatingCustomWord = true
        customWordFeedbackMessage = ""
        
        Task {
            do {
                let nativeLangName = nativeLanguageName(for: nativeLanguage)
                let result = try await geminiService.translateCustomWord(
                    word: trimmedWord,
                    targetLanguage: targetLanguage,
                    nativeLanguageName: nativeLangName
                )
                
                let card = VocabCard(
                    word: result.word,
                    translation: result.translation,
                    targetLanguage: targetLanguage,
                    difficulty: difficulty,
                    contextSentence: result.contextSentence,
                    contextTranslation: result.contextTranslation,
                    grammarNotes: nativeLanguage == .russian ? "Добавлено вручную во время урока" : "Added manually during lesson"
                )
                
                context.insert(card)
                try context.save()
                
                withAnimation {
                    self.customWordFeedbackMessage = nativeLanguage == .russian
                        ? "Добавлено: \(result.word) — \(result.translation) ✅"
                        : "Added: \(result.word) — \(result.translation) ✅"
                }
                
                try await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation {
                    self.customWordFeedbackMessage = ""
                }
            } catch {
                print("Custom word translation error: \(error.localizedDescription)")
                withAnimation {
                    self.customWordFeedbackMessage = nativeLanguage == .russian
                        ? "Ошибка: Не удалось найти слово ❌"
                        : "Error: Could not translate word ❌"
                }
            }
            self.isTranslatingCustomWord = false
        }
    }
}

/// View Model for coordinating the Roleplaying dialogue workspace, speech states, and tutor checks.
@MainActor
class RoleplayViewModel: ObservableObject {
    
    enum State: Equatable {
        case idle
        case loading
        case active(RoleplayScenario)
        case error(String)
    }
    
    /// Struct representing chat bubbles inside the roleplay.
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let sender: String
        let text: String
        let isUser: Bool
    }
    
    /// States representing the active AI Tutor corrections sheet.
    enum TutorState: Equatable {
        case idle
        case loading
        case loaded(String)
        case error(String)
    }
    
    @Published var state: State = .idle
    @Published var messages: [Message] = []
    @Published var isSendingMessage = false
    
    // AI Tutor state
    @Published var tutorState: TutorState = .idle
    
    private let geminiService = GeminiService()
    
    /// Starts a roleplay scenario session. Requests a dynamic creative situation from Gemini when target selection is random.
    func startScenario(scenarioName: String, targetLanguage: String, difficulty: String, nativeLanguage: NativeLanguage) {
        messages = []
        tutorState = .idle
        
        let isRandom = scenarioName.contains("🎲")
        
        if isRandom {
            state = .loading
            let nativeLangName = nativeLanguageName(for: nativeLanguage)
            
            Task {
                do {
                    let scenario = try await geminiService.generateRandomScenario(
                        targetLanguage: targetLanguage,
                        difficulty: difficulty,
                        nativeLanguageName: nativeLangName
                    )
                    self.messages = [Message(sender: scenario.targetRole, text: scenario.startingLine, isUser: false)]
                    self.state = .active(scenario)
                } catch {
                    self.state = .error(error.localizedDescription)
                }
            }
        } else {
            let scenario = mockScenario(for: scenarioName, targetLanguage: targetLanguage, nativeLanguage: nativeLanguage)
            self.messages = [Message(sender: scenario.targetRole, text: scenario.startingLine, isUser: false)]
            self.state = .active(scenario)
        }
    }
    
    /// Sends a response text and requests a character reply from the Gemini API.
    func sendMessage(text: String, scenario: RoleplayScenario, targetLanguage: String, difficulty: String) {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return }
        
        let userMessage = Message(sender: scenario.userRole, text: cleanedText, isUser: true)
        messages.append(userMessage)
        isSendingMessage = true
        
        Task {
            do {
                let aiReply = try await geminiService.generateChatResponse(
                    scenario: scenario,
                    history: messages,
                    targetLanguage: targetLanguage,
                    difficulty: difficulty
                )
                self.messages.append(Message(sender: scenario.targetRole, text: aiReply, isUser: false))
                self.isSendingMessage = false
            } catch {
                self.messages.append(Message(sender: "System", text: "Error: \(error.localizedDescription)", isUser: false))
                self.isSendingMessage = false
            }
        }
    }
    
    /// Audits the dialogue history to check for mistakes and generate corrections in the user's native language.
    func checkDialogueErrors(scenario: RoleplayScenario, targetLanguage: String, nativeLanguage: NativeLanguage) {
        tutorState = .loading
        let nativeLangName = nativeLanguageName(for: nativeLanguage)
        
        Task {
            do {
                let feedback = try await geminiService.analyzeConversationErrors(
                    scenario: scenario,
                    history: messages,
                    targetLanguage: targetLanguage,
                    nativeLanguageName: nativeLangName
                )
                self.tutorState = .loaded(feedback)
            } catch {
                self.tutorState = .error(error.localizedDescription)
            }
        }
    }
    
    func reset() {
        state = .idle
        messages = []
        tutorState = .idle
    }
    
    private func nativeLanguageName(for lang: NativeLanguage) -> String {
        switch lang {
        case .russian: return "Russian"
        case .english: return "English"
        case .german: return "German"
        }
    }
    
    private func mockScenario(for name: String, targetLanguage: String, nativeLanguage: NativeLanguage) -> RoleplayScenario {
        let isGerman = targetLanguage == "German"
        let isRussian = nativeLanguage == .russian
        
        if name.contains("IT") {
            return RoleplayScenario(
                title: name,
                targetRole: isGerman ? "Tech Recruiter (HR)" : "Technical Interviewer",
                userRole: "Software Engineer Candidate",
                contextDescription: isRussian
                    ? "Собеседование на позицию iOS-разработчика. ИИ играет роль интервьюера, проверяет ваши технические навыки."
                    : "Technical interview for a software engineering position. The AI acts as the interviewer.",
                startingLine: isGerman
                    ? "Hallo! Schön, dass Sie da sind. Erzählen Sie mir bitte etwas über sich und Ihre Erfahrung mit iOS."
                    : "Hello! Welcome to the interview. Please tell me a bit about yourself and your experience with iOS."
            )
        } else if name.contains("Ausländerbehörde") {
            return RoleplayScenario(
                title: name,
                targetRole: "Beamter (Officer)",
                userRole: "Relocating Engineer",
                contextDescription: isRussian
                    ? "Регистрация по месту жительства в Германии. Чиновник проверяет ваши документы и задает вопросы."
                    : "Registration office appointment. The officer reviews your application and documents.",
                startingLine: isGerman
                    ? "Guten Tag. Haben Sie Ihren Reisepass, den Mietvertrag und das Anmeldeformular dabei?"
                    : "Good day. Do you have your passport, rental agreement, and registration form?"
            )
        } else if name.contains("Apartment") || name.contains("квартиры") {
            return RoleplayScenario(
                title: name,
                targetRole: "Vermieter (Landlord)",
                userRole: "Apartment hunter",
                contextDescription: isRussian
                    ? "Встреча с арендодателем для осмотра квартиры. Нужно обсудить цену залога и коммунальные услуги."
                    : "Apartment viewing. Ask questions about cold rent, warm rent, deposit, and utilities.",
                startingLine: isGerman
                    ? "Hallo, freut mich. Ja, die Wohnung ist noch frei. Haben Sie eine Schufa-Auskunft dabei?"
                    : "Hello, nice to meet you. Yes, the apartment is still available. Do you have your credit score ready?"
            )
        } else {
            return RoleplayScenario(
                title: name,
                targetRole: "Barista / Waiter",
                userRole: "Customer",
                contextDescription: isRussian
                    ? "Заказ кофе и десерта в местном кафе."
                    : "Ordering coffee and pastries at a local cafe.",
                startingLine: isGerman
                    ? "Hallo! Was darf ich Ihnen heute bringen? Haben Sie schon gewählt?"
                    : "Hello! What can I get for you today? Have you decided?"
            )
        }
    }
}

// ==========================================
// MARK: - 9. VIEWS
// ==========================================

/// Container View that coordinates navigation across the main features, incorporating the Settings panel and Launch prompt.
struct MainTabView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showLaunchSelector = true
    
    var body: some View {
        TabView {
            NavigationStack {
                LearnView()
            }
            .tabItem {
                Label(L10n.string(for: .learnTab, language: settings.nativeLanguage), systemImage: "sparkles")
            }
            
            NavigationStack {
                ReviewView()
            }
            .tabItem {
                Label(L10n.string(for: .reviewTab, language: settings.nativeLanguage), systemImage: "square.stack.3d.up.fill")
            }
            
            NavigationStack {
                RoleplayView()
            }
            .tabItem {
                Label(L10n.string(for: .roleplayTab, language: settings.nativeLanguage), systemImage: "bubble.left.and.bubble.right.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(L10n.string(for: .settingsTab, language: settings.nativeLanguage), systemImage: "gearshape.fill")
            }
        }
        .accentColor(.indigo)
        .sheet(isPresented: $showLaunchSelector) {
            LanguageLaunchSelectorView(isPresented: $showLaunchSelector)
                .interactiveDismissDisabled()
        }
    }
}

/// Overlay Modal View displayed on app launch prompting which language to study during this session.
struct LanguageLaunchSelectorView: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Welcome graphic icon
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.indigo)
            }
            
            VStack(spacing: 8) {
                Text(L10n.string(for: .launchTitle, language: settings.nativeLanguage))
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(L10n.string(for: .launchSubtitle, language: settings.nativeLanguage))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            VStack(spacing: 16) {
                // Deutsch / German Option
                Button(action: {
                    settings.targetLanguage = "German"
                    isPresented = false
                }) {
                    HStack {
                        Text(L10n.string(for: .germanLabel, language: settings.nativeLanguage))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(settings.germanDifficulty)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(6)
                            .foregroundColor(.indigo)
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(settings.targetLanguage == "German" ? Color.indigo : Color.clear, lineWidth: 2)
                    )
                }
                
                // English Option
                Button(action: {
                    settings.targetLanguage = "English"
                    isPresented = false
                }) {
                    HStack {
                        Text(L10n.string(for: .englishLabel, language: settings.nativeLanguage))
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(settings.englishDifficulty)
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.1))
                            .cornerRadius(6)
                            .foregroundColor(.indigo)
                    }
                    .padding(20)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(settings.targetLanguage == "English" ? Color.indigo : Color.clear, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

/// The primary learning panel that renders AI-generated textbook lessons.
struct LearnView: View {
    @StateObject private var viewModel = LearnViewModel()
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @State private var showHistory = false
    @State private var showExam = false

    @Query private var cards: [VocabCard]
    @Query private var completedLessons: [StudiedLesson]

    var filteredCompletedLessons: [StudiedLesson] {
        completedLessons.filter {
            $0.targetLanguage == settings.targetLanguage && $0.difficulty == settings.activeDifficulty
        }
    }

    /// Titles of the lessons covered by the pending level exam.
    var examLessonTitles: [String] {
        completedLessons
            .filter { $0.targetLanguage == settings.targetLanguage && $0.difficulty == settings.activePendingExam }
            .map { $0.id }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !settings.activePendingExam.isEmpty {
                    examBanner
                }

                configHeader

                Divider()
                
                switch viewModel.state {
                case .idle:
                    idleStateView
                case .loading:
                    loadingStateView
                case .loaded(let lesson):
                    lessonContentView(lesson)
                case .error(let errorMsg):
                    errorStateView(errorMsg)
                }
            }
            .padding()
        }
        .navigationTitle(L10n.string(for: .learnTab, language: settings.nativeLanguage))
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .alert(isPresented: $viewModel.showUpgradeAlert) {
            Alert(
                title: Text(settings.nativeLanguage == .russian ? "Поздравляем! 🎉" : "Congratulations! 🎉"),
                message: Text(viewModel.upgradeMessageText),
                dismissButton: .default(Text("OK"))
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.indigo)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            LessonHistoryView(isPresented: $showHistory) { saved in
                viewModel.loadSavedLesson(saved)
            }
        }
        .sheet(isPresented: $showExam) {
            LevelExamView(
                isPresented: $showExam,
                examLevel: settings.activePendingExam,
                completedLessons: examLessonTitles
            )
        }
    }

    /// Prominent banner shown while a level exam is pending; opens the exam sheet.
    private var examBanner: some View {
        Button(action: { showExam = true }) {
            HStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.nativeLanguage == .russian
                         ? "Выпускной экзамен \(settings.activePendingExam)"
                         : "Final Exam \(settings.activePendingExam)")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(settings.nativeLanguage == .russian
                         ? "Сдайте экзамен, чтобы открыть следующий уровень"
                         : "Pass the exam to unlock the next level")
                        .font(.caption)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(.white)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(16)
            .shadow(color: .orange.opacity(0.25), radius: 6, x: 0, y: 3)
        }
    }
    
    private var configHeader: some View {
        VStack(spacing: 16) {
            // Target Language switcher
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation { settings.targetLanguage = "German" }
                }) {
                    Text("🇩🇪 Deutsch")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(settings.targetLanguage == "German" ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(settings.targetLanguage == "German" ? Color.indigo : Color.clear)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    withAnimation { settings.targetLanguage = "English" }
                }) {
                    Text("🇬🇧 English")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(settings.targetLanguage == "English" ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(settings.targetLanguage == "English" ? Color.indigo : Color.clear)
                        .cornerRadius(8)
                }
            }
            .padding(4)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
            
            HStack(spacing: 16) {
                Text(L10n.string(for: .level, language: settings.nativeLanguage))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Picker("Level", selection: $settings.activeDifficulty) {
                    Text("A1").tag("A1")
                    Text("A2").tag("A2")
                    Text("B1").tag("B1")
                    Text("B2").tag("B2")
                    Text("C1").tag("C1")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
            }
            
            Button(action: {
                let studiedWordsList = settings.aiMemoryMode ? cards.map { $0.word } : []
                let completedLessonsList = filteredCompletedLessons.map { $0.id }
                
                viewModel.fetchLesson(
                    context: modelContext,
                    targetLanguage: settings.targetLanguage,
                    difficulty: settings.activeDifficulty,
                    nativeLanguage: settings.nativeLanguage,
                    studiedWords: studiedWordsList,
                    completedLessons: completedLessonsList
                )
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(L10n.string(for: .generateLesson, language: settings.nativeLanguage))
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(12)
                .shadow(color: .indigo.opacity(0.25), radius: 6, x: 0, y: 3)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
    
    private var idleStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 40)
            Image(systemName: "square.text.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            
            Text(L10n.string(for: .readyToStart, language: settings.nativeLanguage))
                .font(.title3)
                .fontWeight(.bold)
            
            Text(L10n.string(for: .selectLevelDesc, language: settings.nativeLanguage))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer(minLength: 40)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 50)
            ProgressView()
                .scaleEffect(1.5)
                .tint(.indigo)
            Text(L10n.string(for: .curatingLesson, language: settings.nativeLanguage))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            Spacer(minLength: 50)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text(L10n.string(for: .somethingWrong, language: settings.nativeLanguage))
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(L10n.string(for: .tryAgain, language: settings.nativeLanguage)) {
                let studiedWordsList = settings.aiMemoryMode ? cards.map { $0.word } : []
                let completedLessonsList = filteredCompletedLessons.map { $0.id }
                
                viewModel.fetchLesson(
                    context: modelContext,
                    targetLanguage: settings.targetLanguage,
                    difficulty: settings.activeDifficulty,
                    nativeLanguage: settings.nativeLanguage,
                    studiedWords: studiedWordsList,
                    completedLessons: completedLessonsList
                )
            }
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.indigo)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func lessonContentView(_ lesson: LanguageLesson) -> some View {
        VStack(spacing: 24) {
            // Lesson Header card
            VStack(spacing: 6) {
                Text(L10n.string(for: .grammarTopicLabel, language: settings.nativeLanguage))
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(lesson.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(lesson.grammarTopic)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(16)
            .shadow(color: .indigo.opacity(0.2), radius: 8, x: 0, y: 4)
            
            // Grammar Focus Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .foregroundColor(.indigo)
                    Text(L10n.string(for: .grammarInsights, language: settings.nativeLanguage))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Text(.init(lesson.grammarExplanation))
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            
            // Dialogue / Reading section
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.indigo)
                    Text(L10n.string(for: .realLifeContext, language: settings.nativeLanguage))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(lesson.conversationText)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.indigo.opacity(0.05))
                        .cornerRadius(12)
                    
                    Text(lesson.conversationTranslation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            
            // Core Vocabulary list
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "character.book.closed.fill")
                        .foregroundColor(.indigo)
                    Text(L10n.string(for: .vocabularyLabel, language: settings.nativeLanguage))
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                }
                
                ForEach(lesson.vocabulary, id: \.self) { vocab in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vocab.word)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.indigo)
                                
                                Text(vocab.phoneticGuide)
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                let localeCode = settings.targetLanguage == "German" ? "de-DE" : "en-US"
                                SpeechManager.shared.speak(vocab.word, languageCode: localeCode)
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.indigo)
                                    .clipShape(Circle())
                            }
                        }
                        
                        Text(vocab.translation)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vocab.contextSentence)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(vocab.contextTranslation)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                }
            }
            
            // Practice exercises quiz blocks
            quizBlock(lesson.exercises)
            
            // Save words to SRS
            saveButtonBlock
            
            // Unfamiliar words custom translator card
            unfamiliarCustomWordCard
            
            // Complete lesson sequential mark
            completeLessonBlock(lesson)
        }
    }
    
    private func quizBlock(_ exercises: [PracticeExercise]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.indigo)
                Text(L10n.string(for: .interactiveQuiz, language: settings.nativeLanguage))
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            ForEach(0..<exercises.count, id: \.self) { questionIndex in
                let exercise = exercises[questionIndex]
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(questionIndex + 1). \(exercise.question)")
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        ForEach(0..<exercise.options.count, id: \.self) { index in
                            Button(action: {
                                if !viewModel.quizChecked {
                                    viewModel.selectedOptions[questionIndex] = index
                                }
                            }) {
                                HStack {
                                    Text(exercise.options[index])
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(optionTextColor(for: questionIndex, optionIndex: index, correctIndex: exercise.correctOptionIndex))
                                    Spacer()
                                    
                                    if viewModel.quizChecked {
                                        if index == exercise.correctOptionIndex {
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                        } else if index == viewModel.selectedOptions[questionIndex] {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                        }
                                    } else if viewModel.selectedOptions[questionIndex] == index {
                                        Image(systemName: "circle.fill").foregroundColor(.indigo).font(.system(size: 8))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(optionBackgroundColor(for: questionIndex, optionIndex: index, correctIndex: exercise.correctOptionIndex))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(optionBorderColor(for: questionIndex, optionIndex: index, correctIndex: exercise.correctOptionIndex), lineWidth: 1))
                            }
                            .disabled(viewModel.quizChecked)
                        }
                    }
                    
                    if viewModel.quizChecked {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.string(for: .explanation, language: settings.nativeLanguage))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Text(exercise.explanation)
                                .font(.caption)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.indigo.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding(.bottom, 10)
            }

            if viewModel.quizChecked {
                let correct = viewModel.correctAnswersCount(in: exercises)
                let passed = viewModel.isQuizPassed(exercises: exercises)

                VStack(spacing: 10) {
                    Text(settings.nativeLanguage == .russian
                         ? "Результат: \(correct) из \(exercises.count)"
                         : "Score: \(correct) of \(exercises.count)")
                        .font(.headline)
                        .foregroundColor(passed ? .green : .red)

                    if !passed {
                        Text(settings.nativeLanguage == .russian
                             ? "Нужно минимум 70% правильных ответов, чтобы завершить урок. Перечитайте материал и попробуйте снова."
                             : "You need at least 70% correct answers to complete the lesson. Review the material and try again.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            withAnimation { viewModel.retryQuiz() }
                        }) {
                            Text(settings.nativeLanguage == .russian ? "Пройти тест заново" : "Retry Quiz")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background((passed ? Color.green : Color.red).opacity(0.06))
                .cornerRadius(12)
            }

            if !viewModel.quizChecked {
                Button(action: {
                    withAnimation { viewModel.quizChecked = true }
                }) {
                    Text(L10n.string(for: .checkAnswer, language: settings.nativeLanguage))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.selectedOptions.count == exercises.count ? Color.indigo : Color.gray.opacity(0.4))
                        .cornerRadius(10)
                }
                .disabled(viewModel.selectedOptions.count < exercises.count)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var saveButtonBlock: some View {
        Button(action: {
            viewModel.saveToSRS(context: modelContext, targetLanguage: settings.targetLanguage, difficulty: settings.activeDifficulty)
        }) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isSaved ? "checkmark.circle.fill" : "plus.square.fill")
                Text(L10n.string(for: viewModel.isSaved ? .savedToSRS : .saveToSRS, language: settings.nativeLanguage))
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.isSaved ? Color.green : Color.indigo)
            .cornerRadius(14)
        }
        .disabled(viewModel.isSaved)
    }
    
    private var unfamiliarCustomWordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "plus.bubble.fill")
                    .foregroundColor(.indigo)
                Text(L10n.string(for: .addCustomWordTitle, language: settings.nativeLanguage))
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Text(L10n.string(for: .addCustomWordSub, language: settings.nativeLanguage))
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 10) {
                TextField(L10n.string(for: .addWordPlaceholder, language: settings.nativeLanguage), text: $viewModel.customWordInput)
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                    .disabled(viewModel.isTranslatingCustomWord)
                
                Button(action: {
                    viewModel.translateAndAddCustomWord(
                        context: modelContext,
                        targetLanguage: settings.targetLanguage,
                        difficulty: settings.activeDifficulty,
                        nativeLanguage: settings.nativeLanguage
                    )
                }) {
                    ZStack {
                        if viewModel.isTranslatingCustomWord {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(viewModel.customWordInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.customWordInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTranslatingCustomWord)
            }
            
            if !viewModel.customWordFeedbackMessage.isEmpty {
                Text(viewModel.customWordFeedbackMessage)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func completeLessonBlock(_ lesson: LanguageLesson) -> some View {
        let quizPassed = viewModel.quizChecked && viewModel.isQuizPassed(exercises: lesson.exercises)

        return VStack(spacing: 12) {
            Button(action: {
                viewModel.markLessonAsCompleted(
                    context: modelContext,
                    lesson: lesson,
                    targetLanguage: settings.targetLanguage,
                    settings: settings
                )
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isCompleted ? "checkmark.seal.fill" : (quizPassed ? "circle.inset.filled" : "lock.fill"))
                    Text(L10n.string(for: .finishLessonButton, language: settings.nativeLanguage))
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isCompleted ? Color.indigo.opacity(0.4) : (quizPassed ? Color.indigo : Color.gray.opacity(0.5)))
                .cornerRadius(14)
            }
            .disabled(viewModel.isCompleted || !quizPassed)

            if !quizPassed && !viewModel.isCompleted {
                Text(settings.nativeLanguage == .russian
                     ? "Чтобы завершить урок, пройдите тест выше минимум на 70%."
                     : "Pass the quiz above with at least 70% to complete the lesson.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }

            if viewModel.isCompleted {
                Text(L10n.string(for: .lessonCompletedToast, language: settings.nativeLanguage))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
        }
    }
    
    private func optionBackgroundColor(for qIndex: Int, optionIndex: Int, correctIndex: Int) -> Color {
        guard viewModel.quizChecked else {
            return viewModel.selectedOptions[qIndex] == optionIndex ? Color.indigo.opacity(0.08) : Color(.tertiarySystemGroupedBackground)
        }
        return optionIndex == correctIndex ? Color.green.opacity(0.1) : (optionIndex == viewModel.selectedOptions[qIndex] ? Color.red.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
    }
    
    private func optionBorderColor(for qIndex: Int, optionIndex: Int, correctIndex: Int) -> Color {
        guard viewModel.quizChecked else {
            return viewModel.selectedOptions[qIndex] == optionIndex ? Color.indigo : Color.clear
        }
        return optionIndex == correctIndex ? Color.green : (optionIndex == viewModel.selectedOptions[qIndex] ? Color.red : Color.clear)
    }
    
    private func optionTextColor(for qIndex: Int, optionIndex: Int, correctIndex: Int) -> Color {
        guard viewModel.quizChecked else { return .primary }
        return optionIndex == correctIndex ? .green : (optionIndex == viewModel.selectedOptions[qIndex] ? .red : .secondary)
    }
}

// ==========================================
// MARK: - LEVEL EXAM
// ==========================================

/// View Model driving the final level exam that gates progression to the next CEFR level.
@MainActor
class ExamViewModel: ObservableObject {

    enum State {
        case loading
        case loaded(LevelExam)
        case error(String)
    }

    /// Minimum share of correct answers required to pass the exam.
    static let passThreshold = 0.8

    @Published var state: State = .loading
    @Published var selectedOptions: [Int: Int] = [:]
    @Published var examChecked = false

    private let geminiService = GeminiService()

    func loadExam(targetLanguage: String, level: String, nativeLanguage: NativeLanguage, completedLessons: [String]) {
        state = .loading
        selectedOptions = [:]
        examChecked = false

        let nativeName: String
        switch nativeLanguage {
        case .russian: nativeName = "Russian"
        case .english: nativeName = "English"
        case .german: nativeName = "German"
        }

        Task {
            do {
                let exam = try await geminiService.generateLevelExam(
                    targetLanguage: targetLanguage,
                    difficulty: level,
                    nativeLanguageName: nativeName,
                    completedLessons: completedLessons
                )
                self.state = .loaded(exam)
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    func correctAnswersCount(in exam: LevelExam) -> Int {
        exam.questions.enumerated().reduce(0) { acc, pair in
            acc + (selectedOptions[pair.offset] == pair.element.correctOptionIndex ? 1 : 0)
        }
    }

    func isPassed(exam: LevelExam) -> Bool {
        guard !exam.questions.isEmpty else { return false }
        return Double(correctAnswersCount(in: exam)) / Double(exam.questions.count) >= Self.passThreshold
    }
}

/// The final level exam screen. Passing it (80%+) unlocks the next CEFR level.
struct LevelExamView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var viewModel = ExamViewModel()
    @Binding var isPresented: Bool

    let examLevel: String
    let completedLessons: [String]

    private var isRussian: Bool { settings.nativeLanguage == .russian }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch viewModel.state {
                    case .loading:
                        VStack(spacing: 16) {
                            Spacer(minLength: 80)
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.orange)
                            Text(isRussian ? "ИИ составляет экзамен по всему уровню..." : "The AI is preparing your level exam...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    case .error(let message):
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text(message)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                            Button(isRussian ? "Попробовать снова" : "Try Again") {
                                loadExam()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding(.top, 60)
                    case .loaded(let exam):
                        examContent(exam)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(isRussian ? "Экзамен \(examLevel)" : "\(examLevel) Final Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isRussian ? "Закрыть" : "Close") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            loadExam()
        }
    }

    private func loadExam() {
        viewModel.loadExam(
            targetLanguage: settings.targetLanguage,
            level: examLevel,
            nativeLanguage: settings.nativeLanguage,
            completedLessons: completedLessons
        )
    }

    private func examContent(_ exam: LevelExam) -> some View {
        VStack(spacing: 20) {
            // Exam rules header
            VStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.title)
                    .foregroundColor(.white)
                Text(isRussian
                     ? "Выпускной экзамен уровня \(examLevel)"
                     : "Level \(examLevel) Final Exam")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(isRussian
                     ? "\(exam.questions.count) вопросов по грамматике и лексике всего уровня. Проходной балл — 80%."
                     : "\(exam.questions.count) questions covering the whole level. Pass mark — 80%.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(16)

            ForEach(0..<exam.questions.count, id: \.self) { questionIndex in
                let question = exam.questions[questionIndex]

                VStack(alignment: .leading, spacing: 12) {
                    Text("\(questionIndex + 1). \(question.question)")
                        .font(.body)
                        .fontWeight(.semibold)

                    VStack(spacing: 8) {
                        ForEach(0..<question.options.count, id: \.self) { optionIndex in
                            Button(action: {
                                if !viewModel.examChecked {
                                    viewModel.selectedOptions[questionIndex] = optionIndex
                                }
                            }) {
                                HStack {
                                    Text(question.options[optionIndex])
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(optionColor(questionIndex: questionIndex, optionIndex: optionIndex, correctIndex: question.correctOptionIndex))
                                    Spacer()
                                    if viewModel.examChecked {
                                        if optionIndex == question.correctOptionIndex {
                                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                        } else if optionIndex == viewModel.selectedOptions[questionIndex] {
                                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                                        }
                                    } else if viewModel.selectedOptions[questionIndex] == optionIndex {
                                        Image(systemName: "circle.fill").foregroundColor(.orange).font(.system(size: 8))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(optionBackground(questionIndex: questionIndex, optionIndex: optionIndex, correctIndex: question.correctOptionIndex))
                                .cornerRadius(10)
                            }
                            .disabled(viewModel.examChecked)
                        }
                    }

                    if viewModel.examChecked {
                        Text(question.explanation)
                            .font(.caption)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
            }

            if !viewModel.examChecked {
                Button(action: {
                    withAnimation { viewModel.examChecked = true }
                }) {
                    Text(isRussian ? "Завершить экзамен" : "Submit Exam")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.selectedOptions.count == exam.questions.count ? Color.orange : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                }
                .disabled(viewModel.selectedOptions.count < exam.questions.count)
            } else {
                resultCard(exam)
            }
        }
    }

    private func resultCard(_ exam: LevelExam) -> some View {
        let correct = viewModel.correctAnswersCount(in: exam)
        let passed = viewModel.isPassed(exam: exam)
        let nextLevel = nextCEFRLevel(after: examLevel)

        return VStack(spacing: 14) {
            Image(systemName: passed ? "party.popper.fill" : "arrow.counterclockwise.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(passed ? .green : .red)

            Text(isRussian
                 ? "Результат: \(correct) из \(exam.questions.count)"
                 : "Score: \(correct) of \(exam.questions.count)")
                .font(.title3)
                .fontWeight(.bold)

            if passed {
                Text(isRussian
                     ? (nextLevel != nil
                        ? "Экзамен сдан! Вы переходите на уровень \(nextLevel!)."
                        : "Экзамен сдан! Вы прошли максимальный уровень программы. Великолепно!")
                     : (nextLevel != nil
                        ? "Exam passed! You are moving up to level \(nextLevel!)."
                        : "Exam passed! You have completed the highest level. Amazing!"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: applyPass) {
                    Text(nextLevel != nil
                         ? (isRussian ? "Перейти на \(nextLevel!)" : "Continue to \(nextLevel!)")
                         : (isRussian ? "Завершить" : "Finish"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(14)
                }
            } else {
                Text(isRussian
                     ? "Для перехода на следующий уровень нужно минимум 80%. Повторите материал и пересдайте экзамен — вопросы будут новыми."
                     : "You need at least 80% to advance. Review the material and retake the exam — the questions will be new.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: { loadExam() }) {
                    Text(isRussian ? "Пересдать экзамен" : "Retake Exam")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(14)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func applyPass() {
        settings.objectWillChange.send()
        settings.activePendingExam = ""
        if let next = nextCEFRLevel(after: examLevel) {
            settings.activeDifficulty = next
        }
        isPresented = false
    }

    private func optionColor(questionIndex: Int, optionIndex: Int, correctIndex: Int) -> Color {
        guard viewModel.examChecked else { return .primary }
        return optionIndex == correctIndex ? .green : (optionIndex == viewModel.selectedOptions[questionIndex] ? .red : .secondary)
    }

    private func optionBackground(questionIndex: Int, optionIndex: Int, correctIndex: Int) -> Color {
        guard viewModel.examChecked else {
            return viewModel.selectedOptions[questionIndex] == optionIndex ? Color.orange.opacity(0.1) : Color(.tertiarySystemGroupedBackground)
        }
        return optionIndex == correctIndex ? Color.green.opacity(0.1) : (optionIndex == viewModel.selectedOptions[questionIndex] ? Color.red.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
    }
}

// ==========================================
// MARK: - LESSON HISTORY
// ==========================================

/// A browsable archive of previously generated lessons persisted in SwiftData.
struct LessonHistoryView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    let onSelect: (SavedLesson) -> Void

    @Query(sort: \SavedLesson.createdAt, order: .reverse) private var savedLessons: [SavedLesson]

    private var isRussian: Bool { settings.nativeLanguage == .russian }

    private var filteredLessons: [SavedLesson] {
        savedLessons.filter { $0.targetLanguage == settings.targetLanguage }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredLessons.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text(isRussian ? "Пока нет сохранённых уроков" : "No saved lessons yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredLessons) { saved in
                            Button(action: {
                                onSelect(saved)
                                isPresented = false
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: saved.isCompleted ? "checkmark.seal.fill" : "book.closed")
                                        .foregroundColor(saved.isCompleted ? .green : .indigo)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(saved.title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        Text("\(saved.difficulty) · \(saved.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteLessons)
                    }
                }
            }
            .navigationTitle(isRussian ? "Мои уроки" : "My Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isRussian ? "Закрыть" : "Close") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func deleteLessons(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredLessons[index])
        }
        try? modelContext.save()
    }
}

/// The review panel that queries the SwiftData model to schedule and show flashcard reviews.
struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Query(sort: \VocabCard.nextReviewDate) private var cards: [VocabCard]
    @State private var showAddCardSheet = false
    @State private var showReviewSession = false
    
    /// Filters review cards based on currently active learning target language.
    var filteredCards: [VocabCard] {
        cards.filter { $0.targetLanguage == settings.targetLanguage }
    }
    
    var dueCardsCount: Int {
        let now = Date()
        return filteredCards.filter { $0.nextReviewDate <= now }.count
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(color: .indigo.opacity(0.3), radius: 12, x: 0, y: 8)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Localized Streak Info
            VStack(spacing: 8) {
                Text(L10n.string(for: .srsSystem, language: settings.nativeLanguage))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(L10n.string(for: .srsSubtitle, language: settings.nativeLanguage))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Streak Display Card
            if settings.streakCount > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(settings.streakCount) \(L10n.string(for: .days, language: settings.nativeLanguage))")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text(L10n.string(for: .streakTrackerSub, language: settings.nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 24)
            }
            
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(dueCardsCount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(dueCardsCount > 0 ? .orange : .secondary)
                    Text(L10n.string(for: .dueReviews, language: settings.nativeLanguage))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                
                VStack(spacing: 4) {
                    Text("\(filteredCards.count)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.indigo)
                    Text(L10n.string(for: .totalWords, language: settings.nativeLanguage))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            
            Button(action: {
                showReviewSession = true
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text(L10n.string(for: .startReview, language: settings.nativeLanguage))
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(dueCardsCount > 0 ? AnyShapeStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)) : AnyShapeStyle(Color.gray.opacity(0.3)))
                .foregroundColor(dueCardsCount > 0 ? .white : .secondary)
                .cornerRadius(14)
            }
            .disabled(dueCardsCount == 0)
            .padding(.horizontal, 24)
            Spacer()
        }
        .navigationTitle(L10n.string(for: .reviewTab, language: settings.nativeLanguage))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddCardSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.indigo)
                }
            }
        }
        .sheet(isPresented: $showAddCardSheet) {
            AddCustomCardView(isPresented: $showAddCardSheet)
        }
        .sheet(isPresented: $showReviewSession) {
            ReviewSessionView(isPresented: $showReviewSession, cardsToReview: filteredCards.filter { $0.nextReviewDate <= Date() })
        }
    }
}

/// Modal view to manually insert a new vocabulary card into the database.
struct AddCustomCardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Binding var isPresented: Bool
    
    @State private var word = ""
    @State private var translation = ""
    @State private var contextSentence = ""
    @State private var contextTranslation = ""
    @State private var grammarNotes = ""
    
    private var titleText: String {
        settings.nativeLanguage == .russian ? "Новая карточка" : "New Flashcard"
    }
    private var wordLabel: String {
        settings.nativeLanguage == .russian ? "Слово / Выражение" : "Word / Phrase"
    }
    private var translationLabel: String {
        settings.nativeLanguage == .russian ? "Перевод" : "Translation"
    }
    private var contextLabel: String {
        settings.nativeLanguage == .russian ? "Пример предложения" : "Example Sentence"
    }
    private var contextTranslationLabel: String {
        settings.nativeLanguage == .russian ? "Перевод примера" : "Example Translation"
    }
    private var grammarLabel: String {
        settings.nativeLanguage == .russian ? "Грамматический разбор (заметки)" : "Grammar / Notes"
    }
    private var saveButtonText: String {
        settings.nativeLanguage == .russian ? "Сохранить" : "Save"
    }
    private var cancelButtonText: String {
        settings.nativeLanguage == .russian ? "Отмена" : "Cancel"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(wordLabel, text: $word)
                    TextField(translationLabel, text: $translation)
                }
                
                Section(header: Text(settings.nativeLanguage == .russian ? "Пример употребления (необязательно)" : "Usage Example (optional)")) {
                    TextField(contextLabel, text: $contextSentence)
                    TextField(contextTranslationLabel, text: $contextTranslation)
                }
                
                Section(header: Text(settings.nativeLanguage == .russian ? "Грамматика / Заметки (необязательно)" : "Grammar / Notes (optional)")) {
                    TextEditor(text: $grammarNotes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(cancelButtonText) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonText) {
                        saveCard()
                    }
                    .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.bold)
                }
            }
        }
    }
    
    private func saveCard() {
        let newCard = VocabCard(
            word: word.trimmingCharacters(in: .whitespacesAndNewlines),
            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
            targetLanguage: settings.targetLanguage,
            difficulty: settings.activeDifficulty,
            contextSentence: contextSentence.trimmingCharacters(in: .whitespacesAndNewlines),
            contextTranslation: contextTranslation.trimmingCharacters(in: .whitespacesAndNewlines),
            grammarNotes: grammarNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        modelContext.insert(newCard)
        do {
            try modelContext.save()
            isPresented = false
        } catch {
            print("Failed to save custom card: \(error.localizedDescription)")
        }
    }
}

/// An interactive flashcard review session utilizing the SM-2 algorithm.
struct ReviewSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings
    @Binding var isPresented: Bool
    
    let cardsToReview: [VocabCard]
    @State private var currentIndex = 0
    @State private var isFlipped = false
    
    private var progressText: String {
        settings.nativeLanguage == .russian 
            ? "Карточка \(currentIndex + 1) из \(cardsToReview.count)"
            : "Card \(currentIndex + 1) of \(cardsToReview.count)"
    }
    
    private var tapToFlipText: String {
        settings.nativeLanguage == .russian ? "Нажмите, чтобы перевернуть" : "Tap to flip"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if cardsToReview.isEmpty {
                    emptyReviewsView
                } else if currentIndex >= cardsToReview.count {
                    completedReviewsView
                } else {
                    let card = cardsToReview[currentIndex]
                    
                    ProgressView(value: Double(currentIndex), total: Double(cardsToReview.count))
                        .tint(.indigo)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    Text(progressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    CardContainer(card: card, isFlipped: $isFlipped, settings: settings)
                        .frame(maxHeight: .infinity)
                        .padding(.horizontal, 24)
                    
                    if isFlipped {
                        gradingButtonsSection(for: card)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button(action: {
                            withAnimation(.spring()) { isFlipped = true }
                        }) {
                            Text(tapToFlipText)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle(settings.nativeLanguage == .russian ? "Повторение слов" : "Word Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(settings.nativeLanguage == .russian ? "Закрыть" : "Close") {
                        isPresented = false
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var emptyReviewsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text(settings.nativeLanguage == .russian ? "Всё повторено!" : "No Reviews Due!")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
        }
    }
    
    private var completedReviewsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 64))
                .foregroundColor(.indigo)
            Text(settings.nativeLanguage == .russian ? "Отличная работа! 🎉" : "Great Job! 🎉")
                .font(.title2)
                .fontWeight(.bold)
            Text(settings.nativeLanguage == .russian ? "Все запланированные слова успешно повторены." : "All due vocabulary has been reviewed successfully.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { isPresented = false }) {
                Text(settings.nativeLanguage == .russian ? "Готово" : "Done")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.indigo)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 48)
            .padding(.top, 24)
            Spacer()
        }
    }
    
    private func gradingButtonsSection(for card: VocabCard) -> some View {
        VStack(spacing: 12) {
            Text(settings.nativeLanguage == .russian ? "Оцените ваше знание слова:" : "Rate your recall:")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                gradeButton(title: settings.nativeLanguage == .russian ? "Забыл" : "Forgot", color: .red, score: 1, card: card)
                gradeButton(title: settings.nativeLanguage == .russian ? "Трудно" : "Hard", color: .orange, score: 3, card: card)
                gradeButton(title: settings.nativeLanguage == .russian ? "Хорошо" : "Good", color: .indigo, score: 4, card: card)
                gradeButton(title: settings.nativeLanguage == .russian ? "Легко" : "Easy", color: .green, score: 5, card: card)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
    
    private func gradeButton(title: String, color: Color, score: Int, card: VocabCard) -> some View {
        Button(action: {
            card.updateSRSProgress(qualityScore: score)
            do {
                try modelContext.save()
            } catch {
                print("Failed to save srs progress: \(error)")
            }
            
            withAnimation {
                isFlipped = false
                currentIndex += 1
            }
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .cornerRadius(10)
        }
    }
}

/// The flashcard graphic structure.
struct CardContainer: View {
    let card: VocabCard
    @Binding var isFlipped: Bool
    let settings: AppSettings
    
    var body: some View {
        ZStack {
            // Front Card
            VStack(spacing: 20) {
                Text(card.word)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.indigo)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    let localeCode = settings.targetLanguage == "German" ? "de-DE" : "en-US"
                    SpeechManager.shared.speak(card.word, languageCode: localeCode)
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(14)
                        .background(Color.indigo)
                        .clipShape(Circle())
                }
            }
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            
            // Back Card
            ScrollView {
                VStack(spacing: 16) {
                    Text(card.word)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                    
                    Text(card.translation)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    if !card.contextSentence.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.contextSentence)
                                .font(.body)
                                .fontWeight(.medium)
                            Text(card.contextTranslation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                    
                    if !card.grammarNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(settings.nativeLanguage == .russian ? "Грамматика / Разбор:" : "Grammar / Notes:")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Text(card.grammarNotes)
                                .font(.caption)
                                .lineSpacing(4)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.indigo.opacity(0.05))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: 320)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onTapGesture {
            withAnimation(.spring()) {
                isFlipped.toggle()
            }
        }
    }
}

/// A roleplaying session workspace enabling speech-to-text practice.
struct RoleplayView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var roleplayVM = RoleplayViewModel()
    @StateObject private var speechRecognizer = SpeechRecognizerManager()
    @State private var selectedScenarioIndex = 0
    @State private var replyText = ""
    @State private var showTutorFeedback = false
    
    var scenarios: [String] {
        switch settings.nativeLanguage {
        case .russian:
            return [
                "Собеседование в IT-компанию 💻",
                "Ausländerbehörde (Регистрация) 🏢",
                "Аренда квартиры (Разговор с хозяином) 🔑",
                "Разговор в кафе (Заказ кофе) ☕️",
                "🎲 Случайная ситуация от ИИ"
            ]
        case .english:
            return [
                "IT Job Interview 💻",
                "Ausländerbehörde (Registration) 🏢",
                "Renting an Apartment (Vermieter) 🔑",
                "Everyday Conversation (Cafe) ☕️",
                "🎲 Random AI-generated Scenario"
            ]
        case .german:
            return [
                "Bewerbungsgespräch (IT) 💻",
                "Ausländerbehörde (Anmeldung) 🏢",
                "Wohnung mieten (Gespräch) 🔑",
                "Alltagsgespräch (Café) ☕️",
                "🎲 Zufälliges KI-Szenario"
            ]
        }
    }
    
    var body: some View {
        VStack {
            switch roleplayVM.state {
            case .idle:
                scenarioSelectionView
            case .loading:
                loadingView
            case .active(let scenario):
                activeSessionView(scenario)
            case .error(let errorMsg):
                errorView(errorMsg)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            speechRecognizer.requestPermissions()
        }
        .sheet(isPresented: $showTutorFeedback) {
            tutorFeedbackSheet(activeScenario: activeScenarioFromState())
        }
    }
    
    private func activeScenarioFromState() -> RoleplayScenario? {
        if case .active(let scenario) = roleplayVM.state {
            return scenario
        }
        return nil
    }
    
    // MARK: - Scenario Selection View
    private var scenarioSelectionView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 8)
                Image(systemName: "waveform")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text(L10n.string(for: .aiVoiceRoleplay, language: settings.nativeLanguage))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(L10n.string(for: .roleplaySubtitle, language: settings.nativeLanguage))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string(for: .selectScenario, language: settings.nativeLanguage))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                
                Picker("Scenario", selection: $selectedScenarioIndex) {
                    ForEach(0..<scenarios.count, id: \.self) { index in
                        Text(scenarios[index]).tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            
            Button(action: {
                roleplayVM.startScenario(
                    scenarioName: scenarios[selectedScenarioIndex],
                    targetLanguage: settings.targetLanguage,
                    difficulty: settings.activeDifficulty,
                    nativeLanguage: settings.nativeLanguage
                )
            }) {
                HStack {
                    Image(systemName: "mic.fill")
                    Text(L10n.string(for: .enterRoleplay, language: settings.nativeLanguage))
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(14)
                .shadow(color: .blue.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .navigationTitle(L10n.string(for: .roleplayTab, language: settings.nativeLanguage))
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            Text(L10n.string(for: .thinking, language: settings.nativeLanguage))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ errorMsg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.largeTitle)
            Text(errorMsg)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
            Button(L10n.string(for: .tryAgain, language: settings.nativeLanguage)) {
                roleplayVM.reset()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
    
    // MARK: - Active Session Chat Layout
    private func activeSessionView(_ scenario: RoleplayScenario) -> some View {
        VStack(spacing: 0) {
            // Scenario context header panel
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(scenario.title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    
                    // Tutor audit button
                    Button(action: {
                        roleplayVM.checkDialogueErrors(
                            scenario: scenario,
                            targetLanguage: settings.targetLanguage,
                            nativeLanguage: settings.nativeLanguage
                        )
                        showTutorFeedback = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "graduationcap.fill")
                            Text(L10n.string(for: .checkMistakesButton, language: settings.nativeLanguage))
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Text(scenario.contextDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Label("\(L10n.string(for: .aiRoleTitle, language: settings.nativeLanguage)): \(scenario.targetRole)", systemImage: "person.circle.fill")
                    Spacer()
                    Button(action: {
                        withAnimation { roleplayVM.reset() }
                    }) {
                        Text(L10n.string(for: .finishSession, language: settings.nativeLanguage))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.indigo)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding()
            
            // Conversation messages stream
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(roleplayVM.messages) { message in
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(message.text)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(18)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(message.sender)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.secondary)
                                            
                                            // Local voice TTS read speaker button
                                            Button(action: {
                                                let localeCode = settings.targetLanguage == "German" ? "de-DE" : "en-US"
                                                SpeechManager.shared.speak(message.text, languageCode: localeCode)
                                            }) {
                                                Image(systemName: "speaker.wave.2.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.indigo)
                                            }
                                        }
                                        Text(message.text)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .background(Color(.secondarySystemGroupedBackground))
                                            .foregroundColor(.primary)
                                            .cornerRadius(18)
                                    }
                                    Spacer()
                                }
                            }
                            .id(message.id)
                        }
                        
                        if roleplayVM.isSendingMessage {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text(L10n.string(for: .thinking, language: settings.nativeLanguage))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .id("loader")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .onChange(of: roleplayVM.messages) { oldValue, newValue in
                    if let last = newValue.last {
                        withAnimation { scrollViewProxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            
            // Input panel block
            HStack(spacing: 12) {
                // Record speech microphone button (captures STT)
                Button(action: {
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                    } else {
                        let localeCode = settings.targetLanguage == "German" ? "de-DE" : "en-US"
                        speechRecognizer.startRecording(languageCode: localeCode)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(speechRecognizer.isRecording ? Color.red.opacity(0.15) : Color.blue.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                            .font(.title2)
                            .foregroundColor(speechRecognizer.isRecording ? .red : .blue)
                            .scaleEffect(speechRecognizer.isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: speechRecognizer.isRecording)
                    }
                }
                
                TextField(L10n.string(for: .textPlaceholder, language: settings.nativeLanguage), text: $replyText)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: speechRecognizer.transcript) { oldValue, newValue in
                        if !newValue.isEmpty {
                            replyText = newValue
                        }
                    }
                
                Button(action: {
                    let text = replyText
                    replyText = ""
                    speechRecognizer.transcript = ""
                    roleplayVM.sendMessage(
                        text: text,
                        scenario: scenario,
                        targetLanguage: settings.targetLanguage,
                        difficulty: settings.activeDifficulty
                    )
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                }
                .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || roleplayVM.isSendingMessage)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Tutor Feedback Modal Sheet
    private func tutorFeedbackSheet(activeScenario: RoleplayScenario?) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text(L10n.string(for: .tutorTitle, language: settings.nativeLanguage))
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { showTutorFeedback = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 24)
            
            Divider()
            
            ScrollView {
                switch roleplayVM.tutorState {
                case .idle:
                    Text("No active analysis.").foregroundColor(.secondary)
                case .loading:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.indigo)
                        Text(L10n.string(for: .tutorAnalyzing, language: settings.nativeLanguage))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                case .loaded(let analysisText):
                    VStack(alignment: .leading, spacing: 16) {
                        // Display feedback card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "graduationcap.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.indigo)
                                Text("Corrections & Explanations")
                                    .fontWeight(.bold)
                            }
                            
                            Text(analysisText)
                                .font(.body)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(Color.indigo.opacity(0.06))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                case .error(let errorMsg):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.largeTitle)
                        Text(errorMsg)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        
                        Button("Retry") {
                            if let sc = activeScenario {
                                roleplayVM.checkDialogueErrors(
                                    scenario: sc,
                                    targetLanguage: settings.targetLanguage,
                                    nativeLanguage: settings.nativeLanguage
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                    }
                    .padding(.top, 40)
                }
            }
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

// ==========================================
// MARK: - 10. SETTINGS VIEW
// ==========================================

/// The Settings View displaying choices for localization, themes, and goals.
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text(L10n.string(for: .sectionLanguageLearning, language: settings.nativeLanguage))) {
                Picker(L10n.string(for: .nativeLangLabel, language: settings.nativeLanguage), selection: $settings.nativeLanguage) {
                    ForEach(NativeLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                
                Picker(L10n.string(for: .targetLangLabel, language: settings.nativeLanguage), selection: $settings.targetLanguage) {
                    Text("Deutsch (DE)").tag("German")
                    Text("English (EN)").tag("English")
                }
                
                Picker(L10n.string(for: .defaultLevelLabel, language: settings.nativeLanguage), selection: $settings.activeDifficulty) {
                    Text("A1").tag("A1")
                    Text("A2").tag("A2")
                    Text("B1").tag("B1")
                    Text("B2").tag("B2")
                    Text("C1").tag("C1")
                }
            }
            
            Section(header: Text(L10n.string(for: .sectionAppearance, language: settings.nativeLanguage))) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string(for: .appThemeLabel, language: settings.nativeLanguage))
                        .font(.body)
                    
                    Picker(L10n.string(for: .appThemeLabel, language: settings.nativeLanguage), selection: $settings.colorScheme) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            Text(scheme.localizedName(for: settings.nativeLanguage)).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text(L10n.string(for: .sectionFeatures, language: settings.nativeLanguage))) {
                VStack(alignment: .leading) {
                    HStack {
                        Text(L10n.string(for: .dailyGoalLabel, language: settings.nativeLanguage))
                        Spacer()
                        Text("\(settings.dailyGoal) \(L10n.string(for: .words, language: settings.nativeLanguage))")
                            .fontWeight(.bold)
                            .foregroundColor(.indigo)
                    }
                    Slider(value: Binding(
                        get: { Double(settings.dailyGoal) },
                        set: { settings.dailyGoal = Int($0) }
                    ), in: 1...20, step: 1)
                    Text(L10n.string(for: .dailyGoalSub, language: settings.nativeLanguage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                Toggle(isOn: $settings.smartReminders) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string(for: .smartRemindersLabel, language: settings.nativeLanguage))
                        Text(L10n.string(for: .smartRemindersSub, language: settings.nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.aiMemoryMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.string(for: .aiMemoryLabel, language: settings.nativeLanguage))
                        Text(L10n.string(for: .aiMemorySub, language: settings.nativeLanguage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(L10n.string(for: .streakTrackerLabel, language: settings.nativeLanguage))
                    Spacer()
                    Button(action: {
                        settings.incrementStreak()
                    }) {
                        HStack {
                            Image(systemName: "flame.fill")
                            Text("+1 \(L10n.string(for: .days, language: settings.nativeLanguage))")
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        settings.streakCount = 0
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(L10n.string(for: .settingsTitle, language: settings.nativeLanguage))
    }
}

// ==========================================
// MARK: - 11. APP ENTRY POINT
// ==========================================

@main
struct SudyAIApp: App {
    @StateObject private var settings = AppSettings()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VocabCard.self,
            StudiedLesson.self,
            SavedLesson.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(settings)
                .preferredColorScheme(settings.colorScheme.colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}
