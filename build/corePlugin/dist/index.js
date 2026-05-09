"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/index.ts
var index_exports = {};
__export(index_exports, {
  actionAddToAlbum: () => actionAddToAlbum,
  actionArchive: () => actionArchive,
  filterFileName: () => filterFileName
});
module.exports = __toCommonJS(index_exports);
var { updateAsset, addAssetToAlbum } = Host.getFunctions();
function parseInput() {
  return JSON.parse(Host.inputString());
}
function returnOutput(output) {
  Host.outputString(JSON.stringify(output));
  return 0;
}
function filterFileName() {
  const input = parseInput();
  const { data, config } = input;
  const { pattern, matchType = "contains", caseSensitive = false } = config;
  const fileName = data.asset.originalFileName || data.asset.fileName || "";
  const searchName = caseSensitive ? fileName : fileName.toLowerCase();
  const searchPattern = caseSensitive ? pattern : pattern.toLowerCase();
  let passed = false;
  if (matchType === "exact") {
    passed = searchName === searchPattern;
  } else if (matchType === "regex") {
    const flags = caseSensitive ? "" : "i";
    const regex = new RegExp(searchPattern, flags);
    passed = regex.test(fileName);
  } else {
    passed = searchName.includes(searchPattern);
  }
  return returnOutput({ passed });
}
function actionAddToAlbum() {
  const input = parseInput();
  const { authToken, config, data } = input;
  const { albumId } = config;
  const ptr = Memory.fromString(
    JSON.stringify({
      authToken,
      assetId: data.asset.id,
      albumId
    })
  );
  addAssetToAlbum(ptr.offset);
  ptr.free();
  return returnOutput({ success: true });
}
function actionArchive() {
  const input = parseInput();
  const { authToken, data } = input;
  const ptr = Memory.fromString(
    JSON.stringify({
      authToken,
      id: data.asset.id,
      visibility: "archive"
    })
  );
  updateAsset(ptr.offset);
  ptr.free();
  return returnOutput({ success: true });
}
//# sourceMappingURL=index.js.map
