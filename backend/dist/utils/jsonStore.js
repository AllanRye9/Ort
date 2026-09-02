"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.readJsonFile = readJsonFile;
exports.writeJsonFile = writeJsonFile;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
function readJsonFile(relativePath, defaultValue) {
    const fullPath = path_1.default.join(process.cwd(), relativePath);
    try {
        if (!fs_1.default.existsSync(fullPath)) {
            return defaultValue;
        }
        const raw = fs_1.default.readFileSync(fullPath, 'utf-8');
        return JSON.parse(raw);
    }
    catch {
        return defaultValue;
    }
}
function writeJsonFile(relativePath, data) {
    const fullPath = path_1.default.join(process.cwd(), relativePath);
    const dir = path_1.default.dirname(fullPath);
    if (!fs_1.default.existsSync(dir)) {
        fs_1.default.mkdirSync(dir, { recursive: true });
    }
    fs_1.default.writeFileSync(fullPath, JSON.stringify(data, null, 2), 'utf-8');
}
//# sourceMappingURL=jsonStore.js.map