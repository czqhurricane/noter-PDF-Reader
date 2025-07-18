/* Do not remove
GPL 3.0 License

Copyright (c) 2020 Mani

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/*SVG.on(document, 'DOMContentLoaded', function () {
    draw = SVG('drawing')
            .height(600)
            .width(600)

    rect = draw.rect(100, 100).move(100, 50).fill('#f06')

    rect
        .on('click', function () {
            this
                .draggable()
                .selectize()
                .resize()
        })
})*/

var clozeMode = "normal";
var selectedElement = "";
var svgGroup = "";
var addedList = [];
var polygonStack = [];

var note_num = 1;
var originalImageName;
var draw;
var rect;
var temp_draw;
var deck;


var canDraw = false;

// Get point in global SVG space
// https://stackoverflow.com/questions/10298658/mouse-position-inside-autoscaled-svg
var pt;
var svg;
// function cursorPoint(evt) {
//     pt.x = evt.clientX; pt.y = evt.clientY;
//     return pt.matrixTransform(svg.getScreenCTM().inverse());
// }

function cursorPoint(evt) {
    pt.x = evt.clientX;
    pt.y = evt.clientY;

    // 获取 SVG 元素的变换矩阵
    var svg = document.getElementById("SVG101");
    var ctm = svg.getScreenCTM();

    // SVG 初始化后的调试
    if (draw) {
        const svgElement = document.getElementById('drawing');
        if (svgElement) {
            const rect = svgElement.getBoundingClientRect();
            console.log('SVG actual dimensions:', {
                width: rect.width,
                height: rect.height,
                top: rect.top,
                left: rect.left
            });
        }
    }

    // 考虑缩放因子
    if (scaleVar !== 1.0) {
        // 将屏幕坐标转换为 SVG 局部坐标
        var transformedPoint = pt.matrixTransform(ctm.inverse());
        // 调整坐标以补偿缩放
        transformedPoint.x = transformedPoint.x / scaleVar;
        transformedPoint.y = transformedPoint.y / scaleVar;

        // 调试信息
        console.log('Cursor point debug:', {
            clientX: evt.clientX,
            clientY: evt.clientY,
            transformedX: transformedPoint.x,
            transformedY: transformedPoint.y,
            scale: svg.style.transform,
            scaleVar: scaleVar
        });

        return transformedPoint;
    }

    // 调试信息
    console.log('Cursor point debug:', {
        clientX: evt.clientX,
        clientY: evt.clientY,
        scale: svg.style.transform,
        scaleVar: scaleVar
    });

    return pt.matrixTransform(ctm.inverse());
}

function handleMouseDown() {
    canDraw = !canDraw;

    svg = document.getElementById("SVG101");
    pt = svg.createSVGPoint();

    if (canDraw) {
        svg.addEventListener('click', handler, false);
    } else {
        svg.removeEventListener('click', handler, false);
    }
}


var isDrawing = true;
var x1, y1, x2, y2, w, h;
function handler(evt) {
    if (evt.target.id != "SVG101") {
        return;
    }

    var loc = cursorPoint(evt);

    if (isDrawing) {
        isDrawing = false;
        console.log("Drawing started");
        x1 = loc.x;
        y1 = loc.y;
        // console.log(loc.x);
        // console.log(loc.y);
    } else {
        isDrawing = true;
        console.log("Drawing stopped");
        // console.log(loc.x);
        // console.log(loc.y);

        x2 = loc.x;
        y2 = loc.y;

        // console.log(x2);
        // console.log(y2);

        // console.log(x1);
        // console.log(y1);

        w = Math.abs(x2 - x1);
        h = Math.abs(y2 - y1);

        // x = Math.abs((x1 + x2) / 2);
        // y = Math.abs((y1 + y2) / 2);

        // console.log("w:"+w);
        // console.log("h:"+h);

        // console.log("x:"+x);
        // console.log("y:"+y);
        if (x1 > x2 && y1 < y2) {
            drawFunction(x2, y1, w, h);
        } else if (x1 > x2 && y1 > y2) {
            drawFunction(x2, y2, w, h);
        } else if (x1 < x2 && y1 > y2) {
            drawFunction(x1, y2, w, h);
        } else {
            drawFunction(x1, y1, w, h);
        }

        // drawFunction(x1, y1, w, h);
    }
}

/**
 * Enable drawing rectangle in SVG window with draggable, selectize and resize
 */

function enableDrawing() {
    handleMouseDown();

    if (canDraw) {
        document.getElementById("enabledrawBtnIcon").style.color = "#fdd835";
    } else {
        document.getElementById("enabledrawBtnIcon").style.color = "#009688";
    }
}


function drawFunction(x1, y1, w, h) {
    if (drawFigureName == "Rectangle") {
        drawRectangle(x1, y1, w, h);
    } else if (drawFigureName == "Ellipse") {
        drawEllipse(x1, y1, w, h);
    } else if (drawFigureName == "Polygon") {
        drawPolygon();
    } else if (drawFigureName == "Textbox") {
        drawText(x1, y1, w, h);
    }
}


function drawRectangle(x1, y1, w, h) {
    var rect = draw.rect(w, h).move(x1, y1).fill(originalColor)
        .on('click', function () {
            this
                .draggable()
                .selectize()
                .resize()
        })

    // console.log(rect);
    polygonStack.push(rect);
}

function drawEllipse(x1, y1, w, h) {
    var ellipse = draw.ellipse(w, h).move(x1, y1).fill(originalColor)
        .on('click', function () {
            this
                .draggable()
                .selectize()
                .resize()
        })

    // console.log(ellipse);
    polygonStack.push(ellipse);
}


function drawPolygon() {
    document.getElementById("enabledrawBtnIcon").style.color = "#fdd835";
    document.getElementById("statusMsg").innerHTML = "Press volume down to stop drawing";

    var poly = draw.polygon().draw().fill(originalColor)
        .on('drawstop', function () {
            document.getElementById("enabledrawBtnIcon").style.color = "#009688";
        })
        .on('click', function () {
            this
                .draggable()
                .selectize()
                .resize()
        })
        .on('drawstart', function () {
            svg.addEventListener('keydown', function (e) {
                if (e.keyCode == 13) {
                    draw.polygon().draw('done');
                    draw.polygon().off('drawstart');
                    document.getElementById("enabledrawBtnIcon").style.color = "#009688";
                    document.getElementById("statusMsg").innerHTML = "";
                }
            });
        });

    // console.log(poly);
    polygonStack.push(poly);
}

function stopDrawPolygon() {
    try {
        document.getElementById("statusMsg").innerHTML = "";
        document.getElementById("enabledrawBtnIcon").style.color = "#009688";
        draw.polygon().draw('stop', event);
        polygonStack.push(polygon);
    } catch (e) {
        console.log(e);
    }
}


function drawText(x1, y1, w, h) {
    var textToInsert = addTextPopup();
    var text = draw.text(textToInsert)
        .move(x1, y1)
        .font({ size: textSize, family: 'Helvetica', fill: textColor })
        .on('click', function () {
            this
                .draggable()
                .selectize()
                .resize()
        })

    // console.log(text);
    polygonStack.push(text);
}

function addTextPopup() {
    var text = prompt("Enter text", "");
    if (name != null) {
        return text;
    }
}


var isDeleting = true;
function removePolygon() {
    console.log("Delete Polygon");
    if (isDeleting) {
        isDeleting = false;
        svg.addEventListener('click', deleteHandler, false);
        document.getElementById("removeBtnIcon").style.color = "#fdd835";

        // add event listner to all child node of svg
        for (i=0; i<polygonStack.length; i++) {
            // console.log(polygonStack[i]);
            delElem = document.getElementById(polygonStack[i].id());
            delElem.addEventListener('touchstart', deleteHandler, false);
        }

    } else {
        isDeleting = true;
        svg.removeEventListener('click', deleteHandler, false);
        document.getElementById("removeBtnIcon").style.color = "#f44336";

        // remove event listner to all child node of svg
        for (i=0; i<polygonStack.length; i++) {
            // console.log(polygonStack[i]);
            delElem = document.getElementById(polygonStack[i].id());
            delElem.removeEventListener('touchstart', deleteHandler, false);
        }
    }
}


function deleteHandler(e) {
    console.log(e.target.id);
    selectedElement = e.target.id;

    try {
        var deleteElem;
        var element = document.getElementById(selectedElement);
        var elementTag = document.getElementById(selectedElement).tagName;

        if (elementTag == "rect" || elementTag == "text" || elementTag == "ellipse" || elementTag == "polygon") {
            if (element.parentElement.tagName == "svg") {
                deleteElem = SVG.adopt(document.getElementById(selectedElement));

                undoStack.push(deleteElem);

                deleteElem.selectize(false);
                deleteElem.remove();

                for (l = 0; l < polygonStack.length; l++) {
                    if (selectedElement == polygonStack[l]['node'].id) {
                        polygonStack.splice(l, 1);
                    }
                }
            } else if (element.parentElement.tagName == "g" && element.parentElement.getAttribute("data-type") == "combine") {
                deleteElem = SVG.adopt(document.getElementById(element.parentElement.id));

                undoStack.push(deleteElem);

                deleteElem.selectize(false);
                deleteElem.remove();

                for (l = 0; l < polygonStack.length; l++) {
                    if (element.parentElement.id == polygonStack[l]['node'].id) {
                        polygonStack.splice(l, 1);
                    }
                }
            }
        }
    } catch (e) {
        console.log(e);
        showSnackbar("Select a figure");
    }
}


var undoStack = [];
function undoDraw() {

    if (polygonStack.length > 0) {
        var polygon = polygonStack.pop();

        if (polygon != undefined) {
            var gElem = SVG.adopt(document.getElementById(polygon));
            gElem.selectize(false);

            undoStack.push(polygon);

            gElem.remove();
        }
    }
}

function redoDraw() {
    if (undoStack.length > 0) {
        var gElem = undoStack.pop();
        draw.add(gElem);
        gElem.selectize(true);

        polygonStack.push(gElem);
    }
}

var imgHeight;
var imgWidth;
function addImage(url="", height=0, width=0, source="", deck="", front="") {
    // iOS 模拟器调试信息
    console.log('=== iOS Simulator Debug Info ===');
    console.log('Received dimensions:', { height, width });
    console.log('Device pixel ratio:', window.devicePixelRatio);
    console.log('Screen dimensions:', {
        width: screen.width,
        height: screen.height,
        availWidth: screen.availWidth,
        availHeight: screen.availHeight
    });
    console.log('Window dimensions:', {
        innerWidth: window.innerWidth,
        innerHeight: window.innerHeight
    });

    console.log('source:', source);

    scaleVar = 1.0;

    polygonStack = [];
    undoStack = [];

    if (deck) {
        localStorage.setItem("deckName", deck);
    }

    if (front) {
        localStorage.setItem("front", front);
    }

    if (source) {
        document.getElementById("noteSources").value = source;
    }

    if (!url) {
        try {
            // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第四版.pdf#(477 0.5260461144321094 . 0.13326226012793177)]][[在读取 innerHTML 属性时，会返回元素所有后代的 HTML 字符串，包括元素、注释和文本节点。 而在写入 innerHTML 时，则会根据提供的字符串值以新的 DOM 子树替代元素中原来包含的所有节点。 < 15.3.6 插入标记 < 15.3 HTML5 < 第15章 DOM扩展 < JavaScript 高级程序设计 第四版.pdf]]
        document.getElementById("drawing").innerHTML = "<img id='uploadPreview' style='-webkit-transform-origin-x: 0%; -webkit-transform-origin-y: 0%;'/>";

            // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第三版.pdf#(710 0.17911434236615995 . 0.20357142857142857)]][[files = EventUtil.getTarget(event) .files, < 25.4.1 FileReader类型 < 25.4 File API < 第25章 新兴的API < JavaScript 高级程序设计 第三版.pdf]]
            // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第三版.pdf#(383 0.5733438485804416 . 0.15778251599147122)]][[event = EventUtil.getEvent(event)； < 13.4.1 UI事件 < 13.4 事件类型 < 第13章 事件 < JavaScript 高级程序设计 第三版.pdf]]
        var selectedFile = event.target.files[0];
        var reader = new FileReader();

        var imgtag = document.getElementById("uploadPreview");
        imgtag.title = selectedFile.name;
        imgtag.type = selectedFile.type;

        originalImageName = imgtag.title;
        console.log("Img Name "+ originalImageName );

            // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第四版.pdf#(648 0.22630230572160545 . 0.1652452025586354)]][[因为这些读取方法是异步的，所以每个 FileReader 会发布几个事件，其中 3 个最有用的事件是 progress、error 和 load，分别表示还有更多数据、发生了错误和读取完成。 < 20.4.2 FileReader类型 < 20.4 File API与Blob API < 第20章 JavaScript API < JavaScript 高级程序设计 第四版.pdf]]
        reader.onload = function (event) {
            // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第三版.pdf#(384 0.16009463722397477 . 0.22281449893390193)]][[然后，创建了一个新的图像元素，并设置了其onload事件处理程序。最后乂将这个图像添加到页面中，还设置了它的src属性。这里有一点需要格外注意：新图像元素不一定要从添加到文档后才开始 下载，只要设置了 src属性就会开始下载。 < 13.4.1 UI事件 < 13.4 事件类型 < 第13章 事件 < JavaScript 高级程序设计 第三版.pdf]]
            imgtag.src = event.target.result;

            // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第三版.pdf#(382 0.5921474358974359 . 0.15043290043290045)]][[load事件 < 13.4.1 UI事件 < 13.4 事件类型 < 第13章 事件 < JavaScript 高级程序设计 第三版.pdf]]
            imgtag.onload = function () {
                // access image size here
                console.log(this.width);
                console.log(this.height);

                imgHeight = this.height;
                imgWidth = this.width;

                saveSelectedImageToDeck();

                draw = SVG('drawing')
                    .height(imgHeight)
                    .width(imgWidth)
                    .id("SVG101")

                document.getElementById("SVG101").style.webkitTransformOriginX = "0%";
                document.getElementById("SVG101").style.webkitTransformOriginY = "0%";

                resetZoom();
            };
        };

        reader.readAsDataURL(selectedFile);
        }catch (e) {
            console.log(e);
            showSnackbar("Image import error");
        }
    } else {
        document.getElementById("drawing").innerHTML = "<img id='uploadPreview' style='-webkit-transform-origin-x: 0%; -webkit-transform-origin-y: 0%;'/>";
        var imgtag = document.getElementById("uploadPreview");
        imgtag.src = url;

        imgHeight = height;
        imgWidth = width;

        var timeStamp = new Date().getTime();
        originalImageName = "image-occlusion-original-" + timeStamp + ".jpg"

        saveSelectedImageToDeck();

        draw = SVG('drawing')
            .height(imgHeight)
            .width(imgWidth)
            .id("SVG101")

        document.getElementById("SVG101").style.webkitTransformOriginX = "0%";
        document.getElementById("SVG101").style.webkitTransformOriginY = "0%";

        resetZoom();
    }
};


/* https://stackoverflow.com/questions/53560991/automatic-file-downloads-limited-to-10-files-on-chrome-browser */
function pause(msec) {
    return new Promise(
        (resolve, reject) => {
            setTimeout(resolve, msec || 1000);
        }
    );
}

var svgNS = "http://www.w3.org/2000/svg";
var xmlns = "http://www.w3.org/2000/svg";

async function saveSVG(name, rect, height, width) {

    await pause(100);
    // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第四版.pdf#(488 0.18884120171673818 . 0.1875)]][[createElementNS(namespaceURI, tagName)，以给定的标签名 tagName 创建指定命名空 间 namespaceURI 的一个新元素； < 16.1.1 XML命名空间 < 16.1 DOM的演进 < 第16章 DOM2和DOM3 < JavaScript 高级程序设计 第四版.pdf]]
    var svg = document.createElementNS(svgNS, "svg");

    // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第四版.pdf#(486 0.9148783977110158 . 0.6776785714285714)]][[ < 16.1.1 XML命名空间 < 16.1 DOM的演进 < 第16章 DOM2和DOM3 < JavaScript 高级程序设计 第四版.pdf]]
    // 为什么使用setAttribute ？
    svg.setAttribute("xmlns", xmlns);
    svg.setAttributeNS(null, "height", height);
    svg.setAttributeNS(null, "width", width);

    var g = document.createElementNS(svgNS, "g");
    g.innerHTML = rect;

    svg.append(g);

    var svgData = svg.outerHTML;

    // return svgData;
    // [[NOTERPAGE:/Users/c/Library/Mobile%20Documents/iCloud~QReader~MarginStudy/Documents/JavaScript%20高级程序设计%20第四版.pdf#(649%200.8533898305084745%20.%200.13015873015873017)]][[blob 表示二进制大对象（binary larget object） < 20.4.4 Blob与部分读取 < 20.4 File API与Blob API < 第20章 JavaScript API < JavaScript 高级程序设计 第四版.pdf]]
    var svgBlob = new Blob([svgData], { type: "image/svg+xml;charset=utf-8" });

    // [[NOTERPAGE:/Users/c/Library/Mobile%20Documents/iCloud~QReader~MarginStudy/Documents/JavaScript%20高级程序设计%20第四版.pdf#(650%200.6351694915254237%20.%200.21587301587301588)]][[对象 URL 与 Blob < 20.4.5 对象URL与Blob < 20.4 File API与Blob API < 第20章 JavaScript API < JavaScript 高级程序设计 第四版.pdf]]
    var svgUrl = URL.createObjectURL(svgBlob);
    /*var downloadLink = document.createElement("a");
    downloadLink.href = svgUrl;
    downloadLink.download = name;
    document.body.appendChild(downloadLink);
    downloadLink.click();*/
    saveFile(name + ".svg", svgBlob);
}

/* https://stackoverflow.com/questions/5623838/rgb-to-hex-and-hex-to-rgb */
function hexToRgb(hex) {
    var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? {
        r: parseInt(result[1], 16),
        g: parseInt(result[2], 16),
        b: parseInt(result[3], 16)
    } : null;
}

var noteHeader;
var noteFooter;
var noteRemarks;
var noteSources;
var noteExtra1;
var noteExtra2;

function getNoteFromForm() {
    noteHeader = document.getElementById("noteHeader").value;
    noteFooter = document.getElementById("noteFooter").value;
    noteRemarks = document.getElementById("noteRemarks").value;
    // Replace newlines and collapse whitespace
    noteSources = document.getElementById("noteSources").value
        .replace(/[\r\n]+/g, "<br>")  // Replace all CR/LF sequences with single space
        .replace(/\s+/g, " ")       // Collapse consecutive whitespace
        .trim();                    // Remove leading/trailing spaces
    noteExtra1 = document.getElementById("noteExtra1").value;
    noteExtra2 = document.getElementById("noteExtra2").value;
}


var textare_id = 0;
function addCsvLineToViewNote(csv) {
    var container = document.getElementById("noteData");
    var textarea = document.createElement("textarea");
    textarea.id = "note-text-area-" + textare_id;
    textarea.setAttribute("style", "display: block; width:90%; height:10vh; margin-top:6px;");
    textarea.value = csv;
    container.appendChild(textarea);
    document.getElementById(textarea.id).readOnly = true;
    textare_id += 1;
    document.getElementById("card-added").innerHTML = textare_id + "  card added" ;
}

function downloadAllNotes() {
    var container = document.getElementById("noteData");

    var textToExport = "";
    for (i = 0; i < container.childElementCount; i++) {
        textToExport += container.children[i].value;
    }

    // exportFile(textToExport, "output-all-notes.txt");
    fileName = "output-all-notes.txt";
    showSnackbar("View Download folder");
}

function addNote() {
    if (document.getElementById("add-note").style.height == "100%") {
        closeAddNoteNav();
    } else {
        document.getElementById("add-note").style.height = "100%";
        document.getElementById("page-title-id").innerHTML = "Add Note";
        document.getElementById("done-btn").style.display = "none";

        document.getElementById("close-add-note-btn").style.display = "block";

        document.getElementById("noteHeader").value = localStorage.getItem("front");
    }
}

function closeAddNoteNav() {
    document.getElementById("add-note").style.height = "0";
    document.getElementById("close-add-note-btn").style.display = "none";
    localStorage.setItem("front", document.getElementById("noteHeader").value);

    resetTitle();
}

function closeNav() {
    document.getElementById("mySidenav").style.width = "0";
}

function resetTitle() {
    document.getElementById('menu-icon').innerHTML = "menu";
    document.getElementById("done-export-all").style.display = "block";
    if (clozeMode == "normal") {
        document.getElementById("page-title-id").innerHTML = "Normal Cloze";
        document.getElementById("done-btn").style.display = "block";
    } else if (clozeMode == "group") {
        document.getElementById("page-title-id").innerHTML = "Group Cloze";
    } else if (clozeMode == "combine") {
        document.getElementById("combine-done-btn").style.display = "block";
        document.getElementById("page-title-id").innerHTML = "Combine Cloze";
    }
}

function viewNote() {
    document.getElementById("viewNoteSideNav").style.height = "100%";
}

function closeViewNoteNav() {
    document.getElementById("viewNoteSideNav").style.height = "0";
}


function sideNavMain() {

    if (document.getElementById("page-title-id").innerHTML == "Settings" || document.getElementById("page-title-id").innerHTML == "Help"
        || document.getElementById("page-title-id").innerHTML == "View Notes" || document.getElementById("page-title-id").innerHTML == "Move Images") {
        hideAll();
        resetTitle();
        settings();
        closeAddNoteNav();
    } else {
        document.getElementById("mainSideNav").style.width = "80%";
    }
}

function closeMainNav() {
    document.getElementById("mainSideNav").style.width = "0";
}

var scaleVar = 1.0;
function zoomOut() {
    scaleVar -= 0.1;
    document.getElementById("SVG101").style.transform = "scale(" + scaleVar + ")";
    document.getElementById("uploadPreview").style.transform = "scale(" + scaleVar + ")";
}

function zoomIn() {
    scaleVar += 0.1;
    document.getElementById("SVG101").style.transform = "scale(" + scaleVar + ")";
    document.getElementById("uploadPreview").style.transform = "scale(" + scaleVar + ")";
}


function resetZoom() {
    var scrWidth = screen.width;
    if (imgWidth > scrWidth) {
        scaleVar = scrWidth/imgWidth;
    } else {
        scaleVar = imgWidth/scrWidth;
    }

    console.log('scrWidth: ', scrWidth)
    console.log('imgWidth: ', imgWidth)
    console.log('scaleVar: ', scaleVar)

    document.getElementById("SVG101").style.transform = "scale(" + scaleVar + ")";
    document.getElementById("uploadPreview").style.transform = "scale(" + scaleVar + ")";
}

function changePage(page) {

    hideAll();
    closeAddNoteNav();

    if (page == "settings") {
        document.getElementById("settingsSideNav").style.height = "100%";
        document.getElementById("page-title-id").innerHTML = "Settings";
        document.getElementById("done-btn").style.display = "none";
        document.getElementById("done-export-all").style.display = "none";
    } else if (page == "help") {
        document.getElementById("viewHelpSideNav").style.height = "100%";
        document.getElementById("page-title-id").innerHTML = "Help";
        document.getElementById("done-btn").style.display = "none";
        document.getElementById("done-export-all").style.display = "none";
    } else if (page == "view") {
        document.getElementById("viewNoteSideNav").style.height = "100%";
        document.getElementById("page-title-id").innerHTML = "View Notes";
        document.getElementById("done-btn").style.display = "none";
        document.getElementById("done-export-all").style.display = "none";
    }

    changeIcon();
}

function hideAll() {
    document.getElementById("settingsSideNav").style.height = "0";
    document.getElementById("viewHelpSideNav").style.height = "0";
    document.getElementById("viewNoteSideNav").style.height = "0";
    document.getElementById("mainSideNav").style.width = "0";
    document.getElementById("add-note").style.height = "0";
}

function changeIcon() {
    if (document.getElementById("page-title-id").innerHTML == "Settings" || document.getElementById("page-title-id").innerHTML == "Help"
        || document.getElementById("page-title-id").innerHTML == "View Notes" || document.getElementById("page-title-id").innerHTML == "Move Images") {
        document.getElementById('menu-icon').innerHTML = "arrow_back";
    }
}

function exportFile(csv, filename) {
    var element = document.createElement('a');
    element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(csv));

    //var filename = "output.txt";
    element.setAttribute('download', filename);

    element.style.display = 'none';
    document.body.appendChild(element);

    element.click();

    document.body.removeChild(element);
}

// change if value changed by user
function settings() {
    questionColor = document.getElementById("QColor").value;
    originalColor = document.getElementById("OColor").value;

    // check if valid hex value, set to default if not valid
    if (!/^#[0-9A-F]{6}$/i.test(questionColor)) {
        questionColor = "#F44336";
        document.getElementById("settingsSideNav").style.height = "100%";
        showSnackbar("Not a valid color");
    }

    if (!/^#[0-9A-F]{6}$/i.test(originalColor)) {
        originalColor = "#FDD835";
        document.getElementById("settingsSideNav").style.height = "100%";
        showSnackbar("Not a valid color");
    }

    localStorage.setItem("originalColor", originalColor);
    localStorage.setItem("questionColor", questionColor);

    textSize = document.getElementById("textSize").value;
    localStorage.setItem("textSize", textSize);

    textColor = document.getElementById("textColor").value;
    localStorage.setItem("textColor", textColor);

    deckName = document.getElementById("deckName").value;
    localStorage.setItem("deckName", deckName);
}

function resetSettings() {
    questionColor = "#EF9A9A";
    originalColor = "#FDD835";
    textColor = "#303942";
    textSize = 30;
    deckName = "Anki Image Occlusion";

    document.getElementById("OColor").value = originalColor;
    localStorage.setItem("originalColor", originalColor);

    document.getElementById("QColor").value = questionColor;
    localStorage.setItem("questionColor", questionColor);

    document.getElementById("textSize").value = textSize;
    localStorage.setItem("textSize", textSize);

    document.getElementById("textColor").value = textColor;
    localStorage.setItem("textColor", textColor);

    document.getElementById("deckName").value = deckName;
    localStorage.setItem("deckName", deckName);
}

window.onbeforeunload = function () {
    return "Have you downloaded output-all-notes.txt?";
};

// assign to input
var questionColor = "#EF9A9A";
var originalColor = "#FDD835";
var textColor = "#303942";
var textSize = 30;
var deckName = "Anki Image Occlusion";

window.onload = function () {
    // get_local_file("/Users/c/.emacs.d/elpa/29.3/develop/eaf-20240321.230436/app/image-occlusion/v3/common.html");

    document.getElementById("side-nav-container").innerHTML = `<!-- Note Form -->
<!-- Header, Footer, Remarks, Sources, Extra 1, Extra 2-->
<div id="add-note" class="sidenav-note">
    <div class="input-note" style="padding-top: 60px;">Header
        <hr class="thin">
        <textarea id="noteHeader" class="input-add-note" type="text" placeholder="Header..." required></textarea>
    </div>

    <div class="input-note" style="padding-top: 30px;">Footer
        <hr class="thin">
        <textarea id="noteFooter" class="input-add-note" type="text" placeholder="Footer..." required></textarea>
    </div>

    <div class="input-note" style="padding-top: 30px;">Remarks
        <hr class="thin">
        <textarea id="noteRemarks" class="input-add-note" type="text" placeholder="Remarks..." required></textarea>
    </div>

    <div class="input-note" style="padding-top: 30px;">Sources
        <hr class="thin">
        <textarea id="noteSources" class="input-add-note" type="text" placeholder="Sources..." required></textarea>
    </div>

    <div class="input-note" style="padding-top: 30px;">Extra 1
        <hr class="thin">
        <textarea id="noteExtra1" class="input-add-note" type="text" placeholder="Extra 1..." required></textarea>
    </div>

    <div class="input-note" style="padding-bottom: 60px; padding-top: 30px;"> Extra 2
        <hr class="thin">
        <textarea id="noteExtra2" class="input-add-note" type="text" placeholder="Extra 2..." required></textarea>
    </div>

</div>
<!-- Note Form -->


<!-- View Added Notes -->
<!--/*
        header, image, question mask, footer, remarks, sources, extra1, extra2, answer mask, origin mask
        */-->
<div id="viewNoteSideNav" class="sidenav-view-note" style="right: 0; text-align: -webkit-center;">
    <div onclick="downloadAllNotes()" class="button"><i class="material-icons" style="color: #1e88e5;">get_app</i>
        Download</div>
    <br>

    <div id="noteData"></div>

    <br><br><br><br><br><br>
</div>
<!-- View Note -->
<!--Help Side Nav -->
<div id="viewHelpSideNav" class="sidenav-help" style="right: 0;">
    <!-- buttons only for showing (no function) -->

    <div style="margin-top: 60px;" class="label-design1"><b>Create Normal Cloze</b></div>
    <div class="help-side-nav-text">
        1. First click <i class="material-icons" style="font-size: 22px; color: #43a047;">add_photo_alternate</i> to add
        image to editor window. <br>2. Then click <i class="material-icons"
            style="font-size: 22px; color: #009688;">crop</i>
        to add rectangles, click two points
        <b>(top left, bottom right corner)</b> to create rectangles of that width and height.<br>3. Also notes related
        to
        images can be added
        by clicking on <i class="material-icons" style="font-size: 22px; color: #5c6bc0;">post_add</i>.<br>4. Finally,
        click
        <i class="material-icons" style="font-size: 22px; color: #1e88e5;">done</i> to add and copy the selected image,
        generated svg and notes data to Deck
        automatically.
        <br> 5. Finally, click <i class="material-icons" style="font-size: 22px; color: #1e88e5;">get_app</i>
        to download the deck.
    </div>

    <div class="label-design1"><b>Create Combine Cloze</b></div>

    <div class="help-side-nav-text">
        To create combine cloze, click <i class="material-icons"
            style="font-size: 22px; color: #607d8b;">collections</i>
        then select
        rectangles in editor window to make a group. Then again click
        <i class="material-icons" style="font-size: 22px; color: #FF6F00;">collections</i> to stop adding to group. Then
        click
        <i class="material-icons" style="font-size: 22px; color: #607d8b;">crop_free</i> to make a group of those
        selected rectangles into one.
        <br>Repeat above to make new group.
        Color can be changed by clicking <i class="material-icons" style="font-size: 22px; color: #607d8b;">palette</i>.
        Then click <i class="material-icons" style="font-size: 22px; color: #1e88e5;">check_circle</i> to generate
        and
        add notes to
        Deck.
        <br> Finally, click <i class="material-icons" style="font-size: 22px; color: #1e88e5;">get_app</i>
        to download the deck.
        <br><b>Repeat above process, for creating more.</b>
    </div>

    <div class="label-design1"><b>Some Tips</b></div>

    <div class="help-side-nav-text">
        1. Last created rectangle can be dragged even if draw button enabled.
        <br>2. When draw button enabled, and want to select other rectangles, then first disable draw button then select
        other rectangles.
        <br>3. Use pinch to zoom for resizing small rectangles.

        <br><b>4. Press volume down button to stop drawing polygon</b>
        <br>5. When selection do not work, then first select other figures then select previous figure.
        <br>6. When changing from rectangle to ellipse or polygon, then may be one extra figure will be created. So, select
        that figure and delete.
        <br>7. After combining a figure, the combined figure can be dragged once.
        <br>8. Some empty figure may not be deleted. It will not added to deck.
        <br><b>9. If delete button not work then select other figure then click previous figure then click delete. It may
        works.</b>
        <br>10. Currently addbox works only for normal cloze
    </div>


    <hr class="thin">

    <table class="help-sidebar">
        <tbody>
            <tr>
                <th>
                    Button
                </th>
                <th>
                    Actions
                </th>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #43a047;">add_photo_alternate</i></div>
                </td>
                <td>
                    Import image file for creating question mask and answer mask
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #039be5;">crop_free</i></div>
                </td>
                <td>
                    Crop images after importing/capturing images to editor window.
                    <br><b>1. </b>First select this to turn on cropping
                    <br><b>2. </b>Resize crop area in editor window
                    <br><b>3. </b>Then again select crop icon to turn off cropping
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #009688;">crop</i></div>
                </td>
                <td>
                    Use this button to create rectangle to any part of screen inside editor area. First click this, then
                    tap on two points (top left corner, bottom right corner) to create rectangle of that width and
                    height. Reset zoom then use this.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #009688;">dashboard</i></div>
                </td>
                <td>
                    Draw rectangles without clicking again draw button. Not fully supported, when draw button turn off,
                    then create one more extra rectangle.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #5c6bc0;">post_add</i></div>
                </td>
                <td>
                    Add note for the imported image.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #607d8b;">collections</i></div>
                </td>
                <td>
                    <b>Create group cloze</b> First click on this then select rectangles, the rectangles with changed
                    color
                    will be added to list. Then again click this to stop adding the selected image to list.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #1e88e5;">done</i></div>
                </td>
                <td>
                    Click this to add card notes, selected image and generated svg to Deck
                </td>
            </tr>
            <!-- <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #1e88e5;">add_box</i></div>
                </td>
                <td>
                    Add rectangle to editor after importing image to window.
                </td>
            </tr> -->
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #f44336;">delete_forever</i></div>
                </td>
                <td>
                    Select to this enable deletion of shape in editor window.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #607d8b;">crop_free</i></div>
                </td>
                <td>
                    Add rectangles to list by clicking top right image button. Then click this to create a group of
                    those rectangles.
                </td>
            </tr>

            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #2196f3;">view_compact</i></div>
                </td>
                <td>
                    Turn on to create rectangles in editor window.
                </td>
            </tr>

            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #2196f3;">lens</i></div>
                </td>
                <td>
                    Turn on to create ellipses in editor window.
                </td>
            </tr>

            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #2196f3;">navigation</i></div>
                </td>
                <td>
                    <b>Experimental feature.</b> Turn on to create polygon in editor window. But multiple polygon using <i>draw</i> button is not
                    available.
                    <b>Press volume down button to stop drawing polygon.</b>
                </td>
            </tr>

            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #2196f3;">format_shapes</i></div>
                </td>
                <td>
                    <b>Experimental feature.</b> Turn on to create text in editor window. Only normal cloze can be
                    created.
                </td>
            </tr>

            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #f44336;">undo</i></div>
                </td>
                <td>
                    Remove last created figure from editor window.
                </td>
            </tr>

            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #f44336;">redo</i></div>
                </td>
                <td>
                    Add last removed figure to editor window.
                </td>
            </tr>

            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #607d8b;">palette</i></div>
                </td>
                <td>
                    In, Normal Cloze and Group Cloze change question mask color,
                    <br>In Combine Cloze make rectangles in group with different color.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #455A64;">zoom_in</i></div>
                </td>
                <td>
                    Layout style is set to fixed. So click this to zoom in.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #455A64;">zoom_out</i></div>
                </td>
                <td>
                    Layout style is set to fixed. So click this to zoom out.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #455A64;">zoom_out_map</i></div>
                </td>
                <td>
                    Reset zoom value. Use it create rectangle at right coordinates.
                </td>
            </tr>
            <tr>
                <td>
                    <div class="button"><i class="material-icons" style="color: #607D8B;">live_help</i></div>
                </td>
                <td>
                    View help window
                </td>
            </tr>
        </tbody>
    </table>



    <div style="text-align: left; padding: 20px;">
        <div>
            <div><b>View Source</b></div>
            <a target="_blank"
                href="https://github.com/krmanik/image-occlusion-in-browser"><b>image-occlusion-in-browser</b></a>
        </div>

        <br><br>
        <div><b>Report bugs and issues</b></div>
        <div>
            <a target="_blank" href="https://github.com/krmanik/image-occlusion-in-browser/issues"><b>Issues</b></a>
        </div>

        <br><br>
        <div><b>License</b></div>
        <div>
            GPL 3.0 License
            <br>
            Copyright (c) 2021 Mani
        </div>
        <br>
        <div>
            <div><b>Other third party license</b></div>
            <a target="_blank"
                href="https://github.com/krmanik/image-occlusion-in-browser/blob/master/License.md">License</a>
        </div>

        <br>
        <div>
            <div><b>Support this project on </b> <a target="_blank"
                href="https://www.patreon.com/krmani">Patreon</a> </div>

        </div>

        <br><br>
    </div>
</div>
<!--Help Side Nav -->`

    // for stopping draw of polygon
    document.addEventListener("volumedownbutton", stopDrawPolygon, false);

    if (drawFigureName == "Rectangle") {
        document.getElementById("drawRectId").style.color = "#fdd835";
    }

    if (localStorage.getItem("questionColor") != null) {
        questionColor = localStorage.getItem("questionColor");
    }

    if (localStorage.getItem("originalColor") != null) {
        originalColor = localStorage.getItem("originalColor");
    }

    if (localStorage.getItem("textColor") != null) {
        textColor = localStorage.getItem("textColor");
    }

    if (localStorage.getItem("textSize") != null) {
        textSize = localStorage.getItem("textSize");
    }

    if (localStorage.getItem("deckName") != null) {
        deckName = localStorage.getItem("deckName");
    }

    document.getElementById("QColor").value = questionColor;
    document.getElementById("OColor").value = originalColor;
    document.getElementById("textColor").value = textColor;
    document.getElementById("textSize").value = textSize;
    document.getElementById("deckName").value = deckName;

}

/* https://stackoverflow.com/questions/9334084/moveable-draggable-div */
function draggable(el) {
    el.addEventListener('mousedown', function (e) {
        var offsetX = e.clientX - parseInt(window.getComputedStyle(this).left);
        var offsetY = e.clientY - parseInt(window.getComputedStyle(this).top);

        function mouseMoveHandler(e) {
            el.style.top = (e.clientY - offsetY) + 'px';
            el.style.left = (e.clientX - offsetX) + 'px';
        }

        function reset() {
            window.removeEventListener('mousemove', mouseMoveHandler);
            window.removeEventListener('mouseup', reset);
        }

        window.addEventListener('mousemove', mouseMoveHandler);
        window.addEventListener('mouseup', reset);
    });
}

/* https://www.kirupa.com/html5/drag.htm */
function touchDraggable(el) {
    var currentX;
    var currentY;
    var initialX;
    var initialY;
    var xOffset = 0;
    var yOffset = 0;

    el.addEventListener("touchstart", dragStart, false);
    el.addEventListener("touchend", dragEnd, false);
    el.addEventListener("touchmove", drag, false);

    function dragStart(e) {
        if (e.type === "touchstart") {
            initialX = e.touches[0].clientX - xOffset;
            initialY = e.touches[0].clientY - yOffset;
        } else {
            initialX = e.clientX - xOffset;
            initialY = e.clientY - yOffset;
        }
    }

    function dragEnd(e) {
        initialX = currentX;
        initialY = currentY;
    }

    function drag(e) {
        e.preventDefault();

        if (e.type === "touchmove") {
            currentX = e.touches[0].clientX - initialX;
            currentY = e.touches[0].clientY - initialY;
        } else {
            currentX = e.clientX - initialX;
            currentY = e.clientY - initialY;
        }

        xOffset = currentX;
        yOffset = currentY;

        setTranslate(currentX, currentY, el);
    }

    function setTranslate(xPos, yPos, el) {
        el.style.transform = "translate3d(" + xPos + "px, " + yPos + "px, 0)";
    }
}


function saveFile(fileName, fileData) {
    addImageToDeck(fileName, fileData);
}

function base64toBlob(base64Data, contentType) {
    contentType = contentType || '';
    var sliceSize = 1024;
    var byteCharacters = atob(base64Data);
    var bytesLength = byteCharacters.length;
    var slicesCount = Math.ceil(bytesLength / sliceSize);
    var byteArrays = new Array(slicesCount);

    for (var sliceIndex = 0; sliceIndex < slicesCount; ++sliceIndex) {
        var begin = sliceIndex * sliceSize;
        var end = Math.min(begin + sliceSize, bytesLength);

        var bytes = new Array(end - begin);
        for (var offset = begin, i = 0; offset < end; ++i, ++offset) {
            bytes[i] = byteCharacters[offset].charCodeAt(0);
        }
        byteArrays[sliceIndex] = new Uint8Array(bytes);
    }
    return new Blob(byteArrays, { type: contentType });
}

function success(result) {
    alert("plugin result: " + result);
};


function showSnackbar(msg) {
    var x = document.getElementById("snackbar");

    x.innerHTML = msg;
    x.className = "show";

    setTimeout(function () { x.className = x.className.replace("show", ""); }, 3000);
}

function onSuccessCallback(entries) {
    //console.log("number of files:" + entries.length);
    document.getElementById("num_images_move").innerHTML = entries.length + " images to move";
}

function onFailCallback() {
    console.log("error file list count");
}

var json_data;
function get_local_file(path) {
    // [[NOTERPAGE:/Users/c/Library/Mobile Documents/iCloud~QReader~MarginStudy/Documents/JavaScript 高级程序设计 第四版.pdf#(737 0.21316165951359084 . 0.13214285714285715)]][[使用 XHR 对象首先要调用 open()方法，这个方法接收 3 个参数：请求类型（"get"、"post"等） 、 请求 URL，以及表示请求是否异步的布尔值。下面是一个例子： < 24.1.1 使用XHR < 24.1 XMLHttpRequest对象 < 第24章 网络请求与远程资源 < JavaScript 高级程序设计 第四版.pdf]]
    const xhr = new XMLHttpRequest()
    xhr.open('GET', path)

    xhr.onload = () => {
        if (xhr.status == 200) {
            html = xhr.response;
            document.getElementById("side-nav-container").innerHTML = html;
        } else {
            // showSnackbar("Failed to load side navigation data.");
        }
    }
    xhr.send();
}

function saveSelectedImageToDeck() {
    var image = document.getElementById("uploadPreview");

    fname = (image.title === undefined || image.title === "")
        ? originalImageName
        : image.title;

    var data = image.src;
    var type = image.type;

    var base64 = data.split(",")[1];

    console.log('fname: ', fname)
    console.log('base64: ', base64)

    var blob = base64toBlob(base64, type);

    saveFile(fname, blob);

    showSnackbar("Image copied to Deck media");
}

function changeMode(mode) {
    hideAll();
    document.getElementById("close-add-note-btn").style.display = "none";

    if (mode == 'normal') {
        console.log('normal');
        clozeMode = "normal";
        document.getElementById('done-btn').style.display = "block";
        document.getElementById('group-done-btn').style.display = "none";
        document.getElementById("merge-rect-btn").style.display = "none";
        document.getElementById('combine-done-btn').style.display = "none";

        document.getElementById('groupButton').style.display = "none";
        document.getElementById("page-title-id").innerHTML = "Normal Cloze";

        showSnackbar("Normal Cloze Mode");


    } else if (mode == 'group') {
        console.log('group');
        clozeMode = "group";

        document.getElementById('done-btn').style.display = "none";
        document.getElementById('group-done-btn').style.display = "block";
        document.getElementById("merge-rect-btn").style.display = "none";
        document.getElementById('combine-done-btn').style.display = "none";

        document.getElementById('groupButton').style.display = "block";
        document.getElementById("page-title-id").innerHTML = "Group Cloze";

        showSnackbar("Group Cloze Mode");

        origSVG = "";
        queSvg = "";
    } else if (mode == 'combine') {

        console.log('combine');
        clozeMode = "combine";

        document.getElementById('done-btn').style.display = "none";
        document.getElementById('group-done-btn').style.display = "none";
        document.getElementById('combine-done-btn').style.display = "block";

        document.getElementById('groupButton').style.display = "block";
        document.getElementById("page-title-id").innerHTML = "Combine Cloze";

        document.getElementById("merge-rect-btn").style.display = "block";

        showSnackbar("Combine Cloze Mode");
    }
}

function moreTools() {
    if (document.getElementById("more-tools").style.display == "none") {
        document.getElementById("more-tools").style.display = "flex";
    } else {
        document.getElementById("more-tools").style.display = "none";
    }
}

var drawFigureName = "Rectangle";

function selectPolygon(e) {
    if (e.id == "rectBtn") {
        drawFigureName = "Rectangle";
    } else if (e.id == "ellipseBtn") {
        drawFigureName = "Ellipse";
    } else if (e.id == "polygonBtn") {
        drawFigureName = "Polygon";
    } else if (e.id == "textBtn") {
        drawFigureName = "Textbox";
        changeMode('normal');
        showSnackbar("Only normal cloze available.");
    }

    if (drawFigureName == "Rectangle") {

        document.getElementById("drawRectId").style.color = "#fdd835";
        document.getElementById("drawEllipseId").style.color = "#2196f3";
        document.getElementById("drawPolygonId").style.color = "#2196f3";
        document.getElementById("drawTextBoxId").style.color = "#2196f3";

    } else if (drawFigureName == "Ellipse") {

        document.getElementById("drawRectId").style.color = "#2196f3";
        document.getElementById("drawEllipseId").style.color = "#fdd835";
        document.getElementById("drawPolygonId").style.color = "#2196f3";
        document.getElementById("drawTextBoxId").style.color = "#2196f3";

    } else if (drawFigureName == "Polygon") {

        document.getElementById("drawRectId").style.color = "#2196f3";
        document.getElementById("drawEllipseId").style.color = "#2196f3";
        document.getElementById("drawPolygonId").style.color = "#fdd835";
        document.getElementById("drawTextBoxId").style.color = "#2196f3";

    } else if (drawFigureName == "Textbox") {

        document.getElementById("drawRectId").style.color = "#2196f3";
        document.getElementById("drawEllipseId").style.color = "#2196f3";
        document.getElementById("drawPolygonId").style.color = "#2196f3";
        document.getElementById("drawTextBoxId").style.color = "#fdd835";
    }
}
