// main.qml
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import QtQuick.Dialogs 1.3

ApplicationWindow {
    id: root
    width: 800
    height: 600
    visible: true
    title: "Визуализатор автомата Мили"

    property var fsmData: null
    property var statePositions: ({})
    property int radius: 30
    property int arrowHeadSize: 10

    FileDialog {
        id: fileDialog
        title: "Открыть JSON файл с описанием автомата"
        nameFilters: ["JSON файлы (*.json)"]
        onAccepted: {
            loadJsonFile(fileDialog.fileUrl)
        }
    }

    function loadJsonFile(fileUrl) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", fileUrl);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                try {
                    fsmData = JSON.parse(xhr.responseText);
                    calculateStatePositions();
                    canvas.requestPaint();
                } catch (e) {
                    console.error("Error parsing JSON:", e);
                    errorDialog.text = "Ошибка при чтении JSON: " + e;
                    errorDialog.open();
                }
            }
        }
        xhr.send();
    }

    function calculateStatePositions() {
        if (!fsmData || !fsmData.states || fsmData.states.length === 0) return;

        // Размещаем состояния по кругу
        const centerX = canvas.width / 2;
        const centerY = canvas.height / 2;
        const radius = Math.min(centerX, centerY) - 80;
        const count = fsmData.states.length;

        statePositions = {};

        fsmData.states.forEach(function(state, index) {
            const angle = (2 * Math.PI * index) / count;
            statePositions[state] = {
                x: centerX + radius * Math.cos(angle),
                y: centerY + radius * Math.sin(angle)
            };
        });
    }

    function drawArrow(ctx, fromX, fromY, toX, toY, label) {
        var angle = Math.atan2(toY - fromY, toX - fromX);

        // Начальная и конечная точки с учетом радиуса узлов
        var startX = fromX + Math.cos(angle) * root.radius;
        var startY = fromY + Math.sin(angle) * root.radius;
        var endX = toX - Math.cos(angle) * root.radius;
        var endY = toY - Math.sin(angle) * root.radius;

        // Рисуем линию
        ctx.strokeStyle = "black";
        ctx.beginPath();
        ctx.moveTo(startX, startY);
        ctx.lineTo(endX, endY);
        ctx.stroke();

        // Рисуем стрелку
        ctx.fillStyle = "black";
        ctx.save();
        ctx.translate(endX, endY);
        ctx.rotate(angle);
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(-arrowHeadSize, -arrowHeadSize/2);
        ctx.lineTo(-arrowHeadSize, arrowHeadSize/2);
        ctx.closePath();
        ctx.fill();
        ctx.restore();

        // Добавляем текст на переходе
        ctx.save();
        ctx.translate((startX + endX) / 2, (startY + endY) / 2);
        ctx.rotate(angle);
        ctx.translate(0, -20);
        ctx.rotate(-angle);
        ctx.fillStyle = "black";
        ctx.textAlign = "center";
        ctx.fillText(label, 0, 0);
        ctx.restore();
    }


    function drawSelfArrow(ctx, x, y, label, stateFrom, stateTo) {
        var radius = root.radius + 10;
        ctx.beginPath();
        ctx.arc(x, y - radius, radius/2, 0.8 * Math.PI, 2.2 * Math.PI);
        ctx.stroke();

        // Стрелка
        ctx.fillStyle = "black";
        ctx.save();
        ctx.translate(x + radius/2 * Math.cos(2.7 * Math.PI), y - radius + radius/2 * Math.sin(2.7 * Math.PI));
        ctx.rotate(2.7 * Math.PI - Math.PI/2);
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(-arrowHeadSize, -arrowHeadSize/2);
        ctx.lineTo(-arrowHeadSize, arrowHeadSize/2);
        ctx.closePath();
        ctx.fill();
        ctx.restore();

        // Текст
         ctx.fillStyle = "black";
         ctx.textAlign = "center";
         ctx.fillText(label, x, y - radius * 2.0);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        ToolBar {
            Layout.fillWidth: true
            RowLayout {
                anchors.fill: parent
                Button {
                    text: "Открыть JSON"
                    onClicked: fileDialog.open()
                }
                Item { Layout.fillWidth: true }
            }
        }

        Canvas {
            id: canvas
            Layout.fillWidth: true
            Layout.fillHeight: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();

                if (!fsmData) return;

                ctx.lineWidth = 2;
                ctx.strokeStyle = "#333";
                ctx.fillStyle = "#ddd";
                ctx.font = "12px sans-serif";

                // Рисуем состояния
                for (var state in statePositions) {
                    var pos = statePositions[state];

                    // Рисуем круг состояния
                    ctx.beginPath();
                    ctx.arc(pos.x, pos.y, root.radius, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.stroke();

                    // Рисуем название состояния
                    ctx.fillStyle = "black";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.fillText(state, pos.x, pos.y);
                    ctx.fillStyle = "#ddd";
                }

                // Рисуем переходы
                if (fsmData.transitions) {
                    for (var i = 0; i < fsmData.transitions.length; i++) {
                        var transition = fsmData.transitions[i];
                        var fromPos = statePositions[transition.from];
                        var toPos = statePositions[transition.to];

                        if (!fromPos || !toPos) continue;

                        var label = transition.input + " / " + transition.output;

                        if (transition.from === transition.to) {
                            drawSelfArrow(ctx, fromPos.x, fromPos.y, label);
                        } else {
                            drawArrow(ctx, fromPos.x, fromPos.y, toPos.x, toPos.y, label);
                        }
                    }
                }
            }

            // Перерисовываем при изменении размера
            onWidthChanged: {
                if (fsmData) {
                    calculateStatePositions();
                    requestPaint();
                }
            }
            onHeightChanged: {
                if (fsmData) {
                    calculateStatePositions();
                    requestPaint();
                }
            }
        }
    }

    Dialog {
        id: errorDialog
        title: "Ошибка"
        standardButtons: StandardButton.Ok

        property string text: ""

        contentItem: Label {
            text: errorDialog.text
            wrapMode: Text.WordWrap
        }
    }

    Component.onCompleted: { // @disable-check M16
        // Пример данных для тестирования, можно закомментировать
        fsmData = {
            "states": ["S1", "S2", "S3"],
            "transitions": [
                {"from": "S1", "to": "S2", "input": "a", "output": "0"},
                {"from": "S2", "to": "S3", "input": "b", "output": "1"},
                {"from": "S3", "to": "S1", "input": "c", "output": "0"},
                {"from": "S1", "to": "S1", "input": "d", "output": "1"}
            ]
        };
        calculateStatePositions();
        canvas.requestPaint();
    }
}
