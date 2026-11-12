/// Chemins de navigation de l'app — source unique (plus de chaînes en dur).
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const groups = '/groups';
  static const profile = '/profile';
  static const invitePattern = '/i/:code';
  static const mediaGallery = '/media-gallery';
  static const share = '/share';

  // Onglets du shell
  static const home = '/home';
  static const calendar = '/calendar';
  static const notes = '/notes';
  static const expenses = '/expenses';
  static const chat = '/chat';

  /// Ordre des onglets du shell (index de branche).
  static const shellTabs = [home, calendar, notes, expenses, chat];

  // Réglages par onglet (même ordre que [shellTabs])
  static const settingsHome = '/settings/home';
  static const settingsCalendar = '/settings/calendar';
  static const settingsNotes = '/settings/notes';
  static const settingsExpenses = '/settings/expenses';
  static const settingsChat = '/settings/chat';
  static const tabSettings = [
    settingsHome,
    settingsCalendar,
    settingsNotes,
    settingsExpenses,
    settingsChat,
  ];

  static String invite(String code) => '/i/$code';
}
