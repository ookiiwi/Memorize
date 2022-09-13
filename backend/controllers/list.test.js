const listCtrl = require('./list');

test('mkdir', () => {
    const expected = {
        a: {
            b : {
                c : {}
            }
        }
    };

    let map = new Map();
    listCtrl.mkdir(map, ['a','b','c']);
    expect(map == expected);

    map = new Map();
    listCtrl.mkdir(map, listCtrl.splitPath('/'));
    console.log(map);
    console.log(listCtrl.splitPath('/'));
    console.log(listCtrl.splitPath('/a/b'));

});

test('getDirContent', () => {
    const expected = { c : {} };

    const map = new Map();
    listCtrl.mkdir(map, ['a','b','c']);
    const content = listCtrl.getDirContent(map, ['a','b']);

    expect(content == expected);
});