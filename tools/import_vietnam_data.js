const fs = require('fs');
const path = require('path');
const vm = require('vm');

const root = path.resolve(__dirname, '..');
const source = process.argv[2] || path.resolve(root, '..', '越南战争-完整版', 'resources', 'app', 'dist', 'vietnam-district-data.js');
const output = path.resolve(root, 'data', 'vietnam_districts.json');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(source, 'utf8'), context, { filename: source });
const provinces = context.districtCities || {};
const roads = context.districtRoads || [];
const ids = Object.keys(provinces).sort((a,b) => Number(a.slice(1))-Number(b.slice(1)));
if (ids.length !== 710) throw new Error(`省份数量异常：${ids.length}`);
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, JSON.stringify({schema:1, provinceCount:710, roadCount:roads.length, provinces:ids.map(id=>({id,...provinces[id]})), roads}, null, 2));
console.log(`Godot 数据导入完成：710 个省份、${roads.length} 条道路`);

