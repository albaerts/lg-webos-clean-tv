// refresh.js <lp.json> <appdir> - copy launch point icons into appdir/icons and write lp.js fallback (WAM cannot load file:// icons)
var fs = require('fs'), path = require('path');
var raw = fs.readFileSync(process.argv[2], 'utf8').replace(/\r/g, '');
var start = raw.indexOf('{'); if (start < 0) process.exit(1);
var j = JSON.parse(raw.slice(start, raw.lastIndexOf('}') + 1));
if (!j.launchPoints) process.exit(1);
var app = process.argv[3], dir = path.join(app, 'icons');
if (!fs.existsSync(dir)) fs.mkdirSync(dir);
var n = 0;
j.launchPoints.forEach(function (lp) {
  var p = lp.largeIcon || lp.mediumLargeIcon || lp.icon; if (!p) return;
  var ext = p.split('.').pop().toLowerCase();
  try { fs.copyFileSync(p, path.join(dir, lp.id + '.' + ext)); n++; } catch (e) {}
});
fs.writeFileSync(path.join(app, 'lp.js'), 'window.LP = ' + JSON.stringify(j.launchPoints) + ';\n');
console.log('icons copied: ' + n + ', launch points: ' + j.launchPoints.length);
