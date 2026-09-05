const fs = require('fs');
const path = require('path');
const source = path.resolve(__dirname, '../../vietnam-provinces-game.json');
const target = path.resolve(__dirname, '../data/design_regions.json');
const items = JSON.parse(fs.readFileSync(source, 'utf8'));
const regions = items.map((item, index) => {
  const faction = item.center_lat >= 17 ? 'north' : 'south';
  const terrain = item.center_lat >= 17 ? 'highland' : item.center_lat <= 11.5 ? 'delta' : 'coast';
  return { id: `r${index}`, name: item.name_vn, source_id: item.id, lat: item.center_lat, lon: item.center_lng,
    faction, terrain, insurgency: faction === 'north' ? 8 : 28,
    rings: item.coordinates.map(ring => ring.map(([lat, lon]) => [lon, lat])) };
});
const payload = { schema: 1, disclaimer: 'Design regions derived from public outlines; not historical 1965 administrative boundaries', regionCount: regions.length, regions };
fs.writeFileSync(target, JSON.stringify(payload));
console.log(`Wrote ${regions.length} design regions to ${target}`);
