// Run on macOS with Xcode: node scripts/check-ios-services.mjs
import {readFile,writeFile,mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {spawnSync} from 'node:child_process';
const root=new URL('../',import.meta.url),folder=await mkdtemp(join(tmpdir(),'triptail-service-checks-'));
try{
 const source=await readFile(new URL('ios/TripTail/PhotoService.swift',root),'utf8');
 const model=source.slice(source.indexOf('struct TravelPhoto:'),source.indexOf('enum PhotoService'));
 const api=source.slice(source.indexOf('enum AIService'));
 const bridge=join(folder,'Service.swift'),executable=join(folder,'checks');
 await writeFile(bridge,'import Foundation\n'+model+api);
 const result=spawnSync('xcrun',['swiftc',new URL('ios/TripTail/DraftLibrary.swift',root).pathname,bridge,new URL('tests/AutomaticBlogChecks.swift',root).pathname,'-o',executable],{stdio:'inherit'});
 if(result.status!==0)throw Error('Swift compilation failed');
 if(spawnSync(executable,[],{stdio:'inherit'}).status!==0)throw Error('Service checks failed');
}finally{await rm(folder,{recursive:true,force:true});}
