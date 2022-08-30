async function saveAs(options, contents) {    
    try{
        const opts = {
            suggestedName:"test_file.txt"
          };

        console.log(opts);
        console.log(options);
        const handle = await window.showSaveFilePicker(options);
        const writable = await handle.createWritable();
        await writable.write(contents);
        await writable.close();
    } catch (e){
        console.log(e);
    }
}