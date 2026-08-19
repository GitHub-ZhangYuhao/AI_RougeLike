# -*- coding: utf-8 -*-
"""字体子集化再生工具：扫描 GameProject 全部文本源文件，提取字符集，
对 assets/fonts/ 下两个中文字体做子集化（保持原文件名，代码零改动）。

用法：python tools/font_subset.py
依赖：pip install fonttools

新增文案后包体里缺字时重跑本脚本即可；原始全量字体备份在
Experimental/backup_full_fonts/（不入库）。
"""
import os
import sys

from fontTools import subset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "GameProject")
FONT_DIR = os.path.join(PROJECT, "assets", "fonts")
FONTS = ["nowar_rounded_bold.ttf", "noto_sans_sc.ttf"]
SCAN_EXT = {".gd", ".tres", ".tscn", ".cfg", ".json", ".txt"}
SKIP_DIRS = {".godot", "build"}
CHARSET_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "font_subset_charset.txt")


def collect_charset() -> str:
    chars = set()
    for dirpath, dirnames, filenames in os.walk(PROJECT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if os.path.splitext(name)[1] not in SCAN_EXT:
                continue
            fp = os.path.join(dirpath, name)
            try:
                text = open(fp, "r", encoding="utf-8", errors="ignore").read()
            except OSError:
                continue
            for ch in text:
                code = ord(ch)
                if 0x20 <= code <= 0x7E or code >= 0x2000:
                    chars.add(ch)
    return "".join(sorted(chars))


def subset_font(filename: str, charset_file: str) -> None:
    src = os.path.join(FONT_DIR, filename)
    tmp = src + ".subset.tmp"
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    font = subset.load_font(src, options)
    with open(charset_file, "r", encoding="utf-8") as fh:
        text = fh.read()
    subsetter = subset.Subsetter(options)
    subsetter.populate(text=text)
    subsetter.subset(font)
    subset.save_font(font, tmp, options)
    font.close()
    os.replace(tmp, src)
    size_mb = os.path.getsize(src) / (1024 * 1024)
    print("%s -> %.2f MB" % (filename, size_mb))


def main() -> int:
    charset = collect_charset()
    with open(CHARSET_OUT, "w", encoding="utf-8", newline="") as fh:
        fh.write(charset)
    print("charset: %d chars (saved to %s)" % (len(charset), os.path.basename(CHARSET_OUT)))
    for name in FONTS:
        subset_font(name, CHARSET_OUT)
    print("done. 记得在 Godot 里重新导入（--import）并重跑冒烟。")
    return 0


if __name__ == "__main__":
    sys.exit(main())