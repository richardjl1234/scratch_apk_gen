/* Scratch Android APK v4 theme switcher.
 * Loaded before main.js so applyScratchTheme() is defined by the time the
 * Edit menu's onClick handlers fire. Boot-restore uses setTimeout to wait
 * for Blockly to be ready.
 */
(function () {
  var P = {
    default: {
      workspace: "#F9F9F9", toolbox: "#FFFFFF", toolboxSelected: "#e9eef2", toolboxText: "#575E75",
      text: "#575E75", flyout: "#F9F9F9", scrollbar: "#CECDCE",
      numPadBackground: "#547AB2", numPadBorder: "#435F91", numPadActiveBackground: "#435F91", numPadText: "white",
      valueReportBackground: "#FFFFFF", valueReportBorder: "#AAAAAA",
      insertionMarker: "#000000", stackGlow: "#FFF200",
      cats: {
        motion: ["#4C97FF", "#4280D7", "#3373CC"],
        looks: ["#9966FF", "#855CD6", "#774DCB"],
        sounds: ["#CF63CF", "#C94FC9", "#BD42BD"],
        control: ["#FFAB19", "#EC9C13", "#CF8B17"],
        event: ["#FFBF00", "#E6AC00", "#CC9900"],
        sensing: ["#5CB1D6", "#47A8D1", "#2E8EB8"],
        pen: ["#0fBD8C", "#0DA57A", "#0B8E69"],
        operators: ["#59C059", "#46B946", "#389438"],
        data: ["#FF8C1A", "#FF8000", "#DB6E00"],
        data_lists: ["#FF661A", "#FF5500", "#E64D00"],
        more: ["#FF6680", "#FF4D6A", "#FF3355"]
      }
    },
    dark: {
      workspace: "#1E1E2E", toolbox: "#181825", toolboxSelected: "#313244", toolboxText: "#CDD6F4",
      text: "#CDD6F4", flyout: "#181825", scrollbar: "#45475A",
      numPadBackground: "#313244", numPadBorder: "#45475A", numPadActiveBackground: "#45475A", numPadText: "#CDD6F4",
      valueReportBackground: "#313244", valueReportBorder: "#585B70",
      insertionMarker: "#F5C2E7", stackGlow: "#F9E2AF",
      cats: {
        motion: ["#89B4FA", "#6FA8F5", "#5494EA"],
        looks: ["#CBA6F7", "#B58FEB", "#9F77DC"],
        sounds: ["#F5C2E7", "#E8A8DB", "#D88ECC"],
        control: ["#F9E2AF", "#E5CC92", "#D2B677"],
        event: ["#FAB387", "#E59D6F", "#CC865A"],
        sensing: ["#94E2D5", "#7DC8BC", "#66AEA3"],
        pen: ["#A6E3A1", "#8DC887", "#74AC6E"],
        operators: ["#94E2D5", "#7DC8BC", "#66AEA3"],
        data: ["#F5C2E7", "#E8A8DB", "#D88ECC"],
        data_lists: ["#F38BA8", "#DA7296", "#C15A82"],
        more: ["#F5C2E7", "#E8A8DB", "#D88ECC"]
      }
    },
    highContrast: {
      workspace: "#000000", toolbox: "#000000", toolboxSelected: "#333333", toolboxText: "#FFFF00",
      text: "#FFFF00", flyout: "#000000", scrollbar: "#FFFF00",
      numPadBackground: "#000000", numPadBorder: "#FFFF00", numPadActiveBackground: "#FFFF00", numPadText: "#000000",
      valueReportBackground: "#000000", valueReportBorder: "#FFFF00",
      insertionMarker: "#FF00FF", stackGlow: "#00FFFF",
      cats: {
        motion: ["#FFFF00", "#CCCC00", "#999900"],
        looks: ["#FF00FF", "#CC00CC", "#990099"],
        sounds: ["#00FFFF", "#00CCCC", "#009999"],
        control: ["#FF8000", "#CC6600", "#994D00"],
        event: ["#FF0000", "#CC0000", "#990000"],
        sensing: ["#00FF00", "#00CC00", "#009900"],
        pen: ["#0000FF", "#0000CC", "#000099"],
        operators: ["#80FF80", "#66CC66", "#4D994D"],
        data: ["#FFFFFF", "#CCCCCC", "#999999"],
        data_lists: ["#FF8080", "#CC6666", "#994D4D"],
        more: ["#808080", "#666666", "#4D4D4D"]
      }
    },
    pastel: {
      workspace: "#FAF8FF", toolbox: "#FFFFFF", toolboxSelected: "#E9E1F4", toolboxText: "#5D5C61",
      text: "#5D5C61", flyout: "#FAF8FF", scrollbar: "#D4CFE2",
      numPadBackground: "#E9E1F4", numPadBorder: "#C8BFE0", numPadActiveBackground: "#C8BFE0", numPadText: "#5D5C61",
      valueReportBackground: "#FFFFFF", valueReportBorder: "#C8BFE0",
      insertionMarker: "#C8BFE0", stackGlow: "#FFD6A5",
      cats: {
        motion: ["#B5EAD7", "#9DDEC4", "#85D2B1"],
        looks: ["#C7CEEA", "#B0B9DD", "#98A3D0"],
        sounds: ["#FFD6E0", "#FFC2D1", "#FFAEC1"],
        control: ["#FFDAC1", "#FFCDAA", "#FFC093"],
        event: ["#FFF1B6", "#FFE89D", "#FFDE83"],
        sensing: ["#C9E4DE", "#B5DACE", "#A1D0BD"],
        pen: ["#E2F0CB", "#D5E8B7", "#C7DFA2"],
        operators: ["#F8D7A8", "#F4C689", "#F0B56A"],
        data: ["#FFC3A0", "#FFB088", "#FF9D70"],
        data_lists: ["#FF9AA2", "#FF8089", "#FF6670"],
        more: ["#E4C1F9", "#D8A8F0", "#CC8EE7"]
      }
    },
    sunset: {
      workspace: "#FFF8F0", toolbox: "#FFFAF5", toolboxSelected: "#FFE4D0", toolboxText: "#3D2C2E",
      text: "#3D2C2E", flyout: "#FFF8F0", scrollbar: "#FFCDB2",
      numPadBackground: "#FFE4D0", numPadBorder: "#FFB088", numPadActiveBackground: "#FFB088", numPadText: "#3D2C2E",
      valueReportBackground: "#FFFAF5", valueReportBorder: "#FFB088",
      insertionMarker: "#E07856", stackGlow: "#FFE066",
      cats: {
        motion: ["#FF6B6B", "#E55555", "#CC4040"],
        looks: ["#FFA94D", "#E59540", "#CC8133"],
        sounds: ["#FFD43B", "#E5BB2F", "#CCA323"],
        control: ["#FF8787", "#E57070", "#CC5959"],
        event: ["#FFB366", "#E59D55", "#CC8744"],
        sensing: ["#FFA8A8", "#E58F8F", "#CC7676"],
        pen: ["#FF9F80", "#E5866A", "#CC6E55"],
        operators: ["#FFC078", "#E5A866", "#CC9155"],
        data: ["#FF7E5F", "#E5694D", "#CC553B"],
        data_lists: ["#FF6B47", "#E55736", "#CC4326"],
        more: ["#FF9580", "#E57E6A", "#CC6755"]
      }
    }
  };

  var REACT_CSS = {
    default: "",
    dark: "html,body{background:#1E1E2E!important;color:#CDD6F4!important}" +
          ".blocks_blocks_C530M .blocklyToolboxDiv{background:#181825!important;border-right-color:#313244!important}" +
          ".blocks_blocks_C530M .blocklyMainBackground{stroke:#45475A!important}" +
          ".browser-modal{background-color:rgba(49,50,68,0.95)!important;color:#CDD6F4!important}",
    highContrast: "html,body{background:#000!important;color:#FFFF00!important}" +
                  ".blocks_blocks_C530M .blocklyToolboxDiv{background:#000!important;border-right:2px solid #FFFF00!important}" +
                  ".blocks_blocks_C530M .blocklyMainBackground{stroke:#FFFF00!important}" +
                  ".browser-modal{background-color:rgba(0,0,0,0.95)!important;color:#FFFF00!important;border:2px solid #FFFF00!important}",
    pastel: "html,body{background:#FAF8FF!important;color:#5D5C61!important}" +
            ".blocks_blocks_C530M .blocklyToolboxDiv{background:#FFFFFF!important;border-right-color:#E9E1F4!important}" +
            ".blocks_blocks_C530M .blocklyMainBackground{stroke:#C8BFE0!important}" +
            ".browser-modal{background-color:rgba(232,228,240,0.95)!important;color:#5D5C61!important}",
    sunset: "html,body{background:#FFF8F0!important;color:#3D2C2E!important}" +
            ".blocks_blocks_C530M .blocklyToolboxDiv{background:#FFFAF5!important;border-right-color:#FFE4D0!important}" +
            ".blocks_blocks_C530M .blocklyMainBackground{stroke:#FFB088!important}" +
            ".browser-modal{background-color:rgba(255,228,208,0.95)!important;color:#3D2C2E!important}"
  };

  var CAT_NAMES = ["motion","looks","sounds","control","event","sensing","pen","operators","data","data_lists","more"];

  function applyPalette(p) {
    if (!p) return;
    var simpleKeys = ["workspace","toolbox","toolboxSelected","toolboxText","text","flyout","scrollbar",
                      "numPadBackground","numPadBorder","numPadActiveBackground","numPadText",
                      "valueReportBackground","valueReportBorder","insertionMarker","stackGlow"];
    for (var i = 0; i < simpleKeys.length; i++) {
      var k = simpleKeys[i];
      if (p[k] && Blockly.Colours[k] !== undefined) Blockly.Colours[k] = p[k];
    }
    if (p.cats) {
      for (var j = 0; j < CAT_NAMES.length; j++) {
        var n = CAT_NAMES[j];
        if (p.cats[n] && Blockly.Colours[n]) {
          Blockly.Colours[n].primary = p.cats[n][0];
          Blockly.Colours[n].secondary = p.cats[n][1];
          Blockly.Colours[n].tertiary = p.cats[n][2];
        }
      }
    }
  }

  function reInjectCss() {
    try {
      if (typeof Blockly !== "undefined" && Blockly.Css) {
        Blockly.Css.styleSheet_ = null;
        Blockly.Css.inject(true, Blockly.Css.mediaPath_);
      }
    } catch (e) {}
  }

  function repaintBlocks() {
    try {
      var ws = Blockly.getMainWorkspace && Blockly.getMainWorkspace();
      if (!ws) return;
      var all = ws.getAllBlocks(false);
      for (var i = 0; i < all.length; i++) {
        try { all[i].updateColour(); } catch (e) {}
      }
    } catch (e) {}
  }

  function overlayReact(themeName) {
    try {
      var prev = document.getElementById("scratch-theme-overlay");
      if (prev) prev.parentNode.removeChild(prev);
      var css = REACT_CSS[themeName];
      if (!css) return;
      var s = document.createElement("style");
      s.id = "scratch-theme-overlay";
      s.appendChild(document.createTextNode(css));
      document.head.appendChild(s);
    } catch (e) {}
  }

  window.applyScratchTheme = function (name) {
    try {
      var p = P[name] || P.default;
      applyPalette(p);
      reInjectCss();
      overlayReact(name || "default");
      repaintBlocks();
      try { localStorage.setItem("scratch.theme", name || "default"); } catch (e) {}
    } catch (e) { console.warn("[theme]", e); }
  };

  window.getScratchTheme = function () {
    try { return localStorage.getItem("scratch.theme") || "default"; } catch (e) { return "default"; }
  };

  // Boot restore: wait for Blockly to be ready, then apply saved theme
  try {
    var saved = localStorage.getItem("scratch.theme");
    if (saved && P[saved] && saved !== "default") {
      var tryRestore = function () {
        if (typeof Blockly !== "undefined" && Blockly.Colours && Blockly.getMainWorkspace && Blockly.getMainWorkspace()) {
          window.applyScratchTheme(saved);
        } else {
          setTimeout(tryRestore, 200);
        }
      };
      setTimeout(tryRestore, 200);
    }
  } catch (e) {}
})();