// Read original JPEG EXIF locally, before canvas strips metadata. Never send GPS automatically.
export async function readGps(file){
  try{
    const buffer=await file.arrayBuffer(),view=new DataView(buffer);
    if(view.getUint16(0)!==0xffd8)return null;
    let offset=2;
    while(offset+4<view.byteLength){
      const marker=view.getUint16(offset);offset+=2;
      if(marker===0xffda||marker===0xffd9)break;
      const size=view.getUint16(offset);if(size<2||offset+size>view.byteLength)return null;
      if(marker===0xffe1&&view.getUint32(offset+2)===0x45786966&&view.getUint16(offset+6)===0){
        const start=offset+8,end=offset+size,little=view.getUint16(start)===0x4949;
        const u16=p=>{if(p<start||p+2>end)throw Error();return view.getUint16(p,little)};
        const u32=p=>{if(p<start||p+4>end)throw Error();return view.getUint32(p,little)};
        if(![0x4949,0x4d4d].includes(view.getUint16(start))||u16(start+2)!==42)return null;
        const entries=relative=>{const p=start+relative,count=u16(p);if(count>256)throw Error();const map=new Map();for(let n=0;n<count;n++){const entry=p+2+n*12;u32(entry+8);map.set(u16(entry),entry)}return map};
        const pointer=entries(u32(start+4)).get(0x8825);if(!pointer)return null;
        const gps=entries(u32(pointer+8));
        const ref=tag=>{const p=gps.get(tag);if(!p||u16(p+2)!==2||u32(p+4)!==2)throw Error();return String.fromCharCode(view.getUint8(p+8))};
        const coord=tag=>{const p=gps.get(tag);if(!p||u16(p+2)!==5||u32(p+4)!==3)throw Error();const base=start+u32(p+8),values=[];for(let n=0;n<3;n++){const denominator=u32(base+n*8+4);if(!denominator)throw Error();values.push(u32(base+n*8)/denominator)}if(values[1]>=60||values[2]>=60)throw Error();return values[0]+values[1]/60+values[2]/3600};
        const latRef=ref(1),lonRef=ref(3);if(!['N','S'].includes(latRef)||!['E','W'].includes(lonRef))return null;
        const latitude=coord(2)*(latRef==='S'?-1:1),longitude=coord(4)*(lonRef==='W'?-1:1);
        return Math.abs(latitude)<=90&&Math.abs(longitude)<=180?{latitude,longitude}:null;
      }
      offset+=size;
    }
  }catch{}
  return null;
}
