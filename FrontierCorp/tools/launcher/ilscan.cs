// 1.1.15: проверка лаунчера после mcs — методы строк, которых нет в .NET Framework 4 (на Windows: «Метод не найден»).
// mcs с новыми справочными сборками выбирает перегрузки .NET Core: Split(char, StringSplitOptions), Trim(char), Contains(char)…
using System; using System.Reflection;
class IlScan { static int Main(string[] a) {
  var m = Assembly.LoadFrom(a[0]).ManifestModule; int bad = 0;
  for (int i = 1; i < 20000; i++) {
    MemberInfo mb;
    try { mb = m.ResolveMember(0x0A000000 + i); } catch (ArgumentOutOfRangeException) { break; } catch (Exception) { continue; }
    if (mb == null || mb.DeclaringType != typeof(string)) continue;
    var s = mb.ToString();
    bool core = (s.Contains("Split(Char,") || s.Contains("Split(Char)") || s.Contains("Split(System.String")
      || s.Contains("Trim(Char)") || s.Contains("TrimStart(Char)") || s.Contains("TrimEnd(Char)")
      || s.Contains("Contains(Char") || s.Contains("StartsWith(Char)") || s.Contains("EndsWith(Char)")
      || s.Contains("Replace(System.String, System.String, System.StringComparison)") || s.Contains("Join(Char"));
    if (core) { Console.WriteLine("NOT IN .NET FRAMEWORK: String::" + s); bad++; }
  }
  return bad == 0 ? 0 : 1;
} }
