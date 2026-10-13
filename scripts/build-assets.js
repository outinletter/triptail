import {mkdir,copyFile} from 'node:fs/promises';
const root=new URL('../',import.meta.url),output=new URL('dist/',root);
await mkdir(output,{recursive:true});
for(const file of ['privacy.html','index.html','app.js','location-ui.js','photo-gps.js','styles.css','sw.js','icon.png','manifest.json']){
  await copyFile(new URL(file,root),new URL(file,output));
}
