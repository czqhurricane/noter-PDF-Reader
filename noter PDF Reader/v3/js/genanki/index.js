// The `initSqlJs` function is globally provided by all of the main dist files if loaded in the browser.
// We must specify this locateFile function if we are loading a wasm file from anywhere other than the current html page's folder.
config = {
    locateFile: filename => `js/genanki/sql/sql-wasm.wasm`
}

var SQL;
initSqlJs(config).then(function (sql) {
    //Create the database
    SQL = sql;
});

const m = new Model({
    name: MODEL_NAME,
    id: "2156341623643",
    flds: FIELDS,
    css: CSS1,
    req: [
        [0, "all", [0]],
    ],
    tmpls: [
        {
            name: "Card 1",
            qfmt: QFMT1,
            afmt: AFMT1,
        }
    ],
})

const d = new Deck(1347617346765, deckName)
const p = new Package()

function addImageToDeck(fname, blob) {
    p.addMedia(blob, fname);
}

// add note to deck
var addedCount = 0;
function addNoteToDeck() {
    var container = document.getElementById("noteData");

    var textToExport = "";
    // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第四版.pdf#(472 0.4685264663805436 . 0.19017857142857142)]][[childElementCount，返回子元素数量（不包含文本节点和注释） < 15.2 元素遍历 < 第15章 DOM扩展 < JavaScript 高级程序设计 第四版.pdf]]
    for (i = 0; i < container.childElementCount; i++) {
        // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第四版.pdf#(481 0.8512160228898427 . 0.17678571428571427)]][[children 属性 < 15.4.1 children属性 < 15.4 专有扩展 < 第15章 DOM扩展 < JavaScript 高级程序设计 第四版.pdf]]
        // 注意和childNodes 的区别
        // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第四版.pdf#(428 0.6881258941344778 . 0.17142857142857143)]][[每个节点都有一个 childNodes 属性，其中包含一个 NodeList 的实例。NodeList 是一个类数组 对象，用于存储可以按位置存取的有序节点。注意，NodeList 并不是 Array 的实例，但可以使用中括 号访问它的值，而且它也有 length 属性。 < 14.1.1 Node类型 < 14.1 节点层级 < 第14章 DOM < JavaScript 高级程序设计 第四版.pdf]]
        textToExport += container.children[i].value;
    }

    if (textToExport == "") {
        showSnackbar("Add notes to deck first");
        return;
    }

    // console.log(textToExport);

    var lines = textToExport.split("\n");
    for (l of lines) {
        var noteData = l.split("\t");
        // this deck have 11 fields view config.js for more
        if (noteData.length == 11) {
            addedCount++;
            d.addNote(m.note(noteData))
        }
    }
}

// add deck to package and export
function _exportDeck() {
    p.addDeck(d)
    p.writeToFile('Anki-Deck-Export.apkg')
}

function exportDeck() {
    showSnackbar("Wait... deck is exporting");
    addNoteToDeck();
    _exportDeck();
}
