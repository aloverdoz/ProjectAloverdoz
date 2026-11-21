// Ставит иконку и сведения о версии в .exe (без встроенного pck — его кладём рядом).
// usage: node patch_exe.mjs in.exe out.exe game.ico version
import * as ResEdit from 'resedit';
import * as PE from 'pe-library';
import fs from 'fs';
const [,, inp, out, ico, ver] = process.argv;
const exe = PE.NtExecutable.from(fs.readFileSync(inp), { ignoreCert: true });
const res = PE.NtExecutableResource.from(exe);
const iconFile = ResEdit.Data.IconFile.from(fs.readFileSync(ico));
const groups = ResEdit.Resource.IconGroupEntry.fromEntries(res.entries);
const gid = groups.length ? groups[0].id : 1;
const lang = groups.length ? groups[0].lang : 1033;
ResEdit.Resource.IconGroupEntry.replaceIconsForResource(res.entries, gid, lang, iconFile.icons.map(i => i.data));
const vis = ResEdit.Resource.VersionInfo.fromEntries(res.entries);
const vi = vis[0];
const v = ver.split('.').map(Number);
vi.setFileVersion(v[0], v[1], v[2] || 0, v[3] || 0, 1033);
vi.setProductVersion(v[0], v[1], v[2] || 0, v[3] || 0, 1033);
for (const l of vi.getAllLanguagesForStringValues()) {
  vi.setStringValues(l, {
    CompanyName: 'Frontier Corp', FileDescription: 'Frontier Corp', ProductName: 'Frontier Corp',
    InternalName: 'FrontierCorp', OriginalFilename: 'FrontierCorp.exe',
    FileVersion: ver, ProductVersion: ver, LegalCopyright: '© 2026 Frontier Corp',
  });
  vi.removeStringValue(l, 'Licence'); vi.removeStringValue(l, 'Info');
}
vi.outputToResourceEntries(res.entries);
res.outputResource(exe);
fs.writeFileSync(out, Buffer.from(exe.generate()));
console.log('patched', out);
