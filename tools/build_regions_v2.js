const fs=require('fs'),path=require('path');
const d=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../data/vietnam_districts.json'))).provinces;
const p=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../data/vietnam_polygons.json'))).polygons;
function spread(a,n){return Array.from({length:n},(_,k)=>a[Math.floor(k*a.length/n)]);}
const picked=d.map((x,i)=>({x,i}));
const regions=picked.map((v,i)=>{const x=v.x,g=p[v.i];return {id:'f'+i,name:x.n,source_id:x.id,lat:x.la,lon:x.lo,faction:x.c,terrain:x.la<12?'delta':x.la>17?'highland':'coast',support:x.c==='south'?55:15,security:x.c==='south'?45:10,insurgency:x.vc||20,rings:g?g.rings:[]};});
fs.writeFileSync(path.resolve(__dirname,'../data/frontier_regions.json'),JSON.stringify({schema:2,disclaimer:'游戏设计区域，不代表1965历史边界',regionCount:regions.length,regions}));
console.log('regions='+regions.length);
