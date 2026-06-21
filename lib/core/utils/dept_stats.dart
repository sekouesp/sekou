import '../constants.dart';
import '../../models/user_profile.dart';

/// Un contributeur d'un département : l'utilisateur et les points qu'il rapporte.
typedef DeptContributor = ({UserProfile user, int points});

/// Statistiques agrégées d'un département pour le classement.
class DeptStat {
  final String dept;
  final int points;
  final List<DeptContributor> contributors; // triés par points décroissants

  const DeptStat({
    required this.dept,
    required this.points,
    required this.contributors,
  });
}

/// Retire les accents pour comparer des noms de département de façon robuste.
String _stripAccents(String input) {
  const from = 'àáâãäçèéêëìíîïñòóôõöùúûüýÿ';
  const to = 'aaaaaceeeeiiiinooooouuuuyy';
  final buffer = StringBuffer();
  for (final ch in input.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final idx = from.indexOf(c);
    buffer.write(idx >= 0 ? to[idx] : c);
  }
  return buffer.toString();
}

/// Normalise une chaîne département saisie vers la constante canonique
/// correspondante (insensible à la casse/accents/espaces). Évite les doublons
/// du type « Génie Electrique » vs « Génie Électrique ».
String canonicalDept(String raw) {
  final key = _stripAccents(raw.trim()).replaceAll(RegExp(r'\s+'), ' ');
  for (final d in AppConstants.departments) {
    if (_stripAccents(d.trim()).replaceAll(RegExp(r'\s+'), ' ') == key) {
      return d;
    }
  }
  return raw.trim();
}

/// Agrège les points par département à partir d'une liste d'utilisateurs.
///
/// Source de vérité unique partagée par la page Classement et le dashboard
/// admin : on inclut tout utilisateur ayant un département (hors super-admin),
/// on regroupe par département canonique, et on trie départements et
/// contributeurs par points décroissants.
List<DeptStat> aggregateDeptStats(List<UserProfile> users) {
  final pointsByDept = <String, int>{};
  final contributorsByDept = <String, List<DeptContributor>>{};

  for (final u in users) {
    if (u.isSuperAdmin) continue;
    if (u.department.trim().isEmpty) continue;
    final pts = u.interactionStats?.points ?? 0;
    final dept = canonicalDept(u.department);
    pointsByDept[dept] = (pointsByDept[dept] ?? 0) + pts;
    if (pts > 0) {
      (contributorsByDept[dept] ??= []).add((user: u, points: pts));
    }
  }

  final stats = pointsByDept.entries.map((e) {
    final contributors = contributorsByDept[e.key] ?? <DeptContributor>[];
    contributors.sort((a, b) => b.points.compareTo(a.points));
    return DeptStat(dept: e.key, points: e.value, contributors: contributors);
  }).toList()
    ..sort((a, b) => b.points.compareTo(a.points));

  return stats;
}
