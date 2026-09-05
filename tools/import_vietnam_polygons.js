const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const source = process.argv[2] || path.resolve(root, '..', 'gadm41_VNM_2.json');
const output = path.resolve(root, 'data', 'vietnam_polygons.json');
const geo = JSON.parse(fs.readFileSync(source, 'utf8'));
if (geo.features.length !== 710) throw new Error(`边界数量异常：${geo.features.length}`);
const polygons = geo.features.map(f => ({
  id: f.properties.GID_2,
  name: f.properties.NAME_2,
  rings: f.geometry.coordinates.map(p => p[0]).filter(r => r.length >= 3)
}));
fs.mkdirSync(path.dirname(output), {recursive:true});
fs.writeFileSync(output, JSON.stringify({schema:1, polygonCount:710, polygons}));
console.log(`Godot 边界导入完成：${polygons.length} 个地区`);

