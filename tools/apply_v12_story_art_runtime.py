# -*- coding: utf-8 -*-
"""Bind the curated v1.2 story-art library to the native GDI+ runtime.

The patch is deliberately data-only at runtime: JPEG files are loaded from
``release/story_art`` without transcoding. Named legacy portraits remain as
fallbacks when the curated library is unavailable.
"""
from __future__ import annotations

from pathlib import Path

from install_curated_story_art import main as install_curated_story_art

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "wendao_enhanced.cpp"
MARKER = "V0_12_CURATED_STORY_ART_RUNTIME"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Unable to apply v0.12 story-art patch: {label} anchor missing")
    return text.replace(old, new, 1)


def patch_source(text: str) -> str:
    if MARKER in text:
        print("v0.12 curated story-art runtime patch already applied.")
        return text

    portrait_decl = "Image* GetEventPortraitImage(const Event* event, wstring& name, wstring& title) {"
    portrait_helper = r'''// V0_12_CURATED_STORY_ART_RUNTIME
Image* LoadCuratedStoryArtImage(const wchar_t* relativePath) {
    static map<wstring, Image*> cache;
    if (!relativePath || !*relativePath) return nullptr;

    wstring path(relativePath);
    auto cached = cache.find(path);
    if (cached != cache.end()) return cached->second;

    Image* image = nullptr;
    if (GetFileAttributesW(path.c_str()) != INVALID_FILE_ATTRIBUTES) {
        image = Image::FromFile(path.c_str());
        if (!image || image->GetLastStatus() != Ok) {
            delete image;
            image = nullptr;
        }
    }
    cache[path] = image;
    return image;
}

Image* GetEventPortraitImage(const Event* event, wstring& name, wstring& title) {'''
    text = replace_once(text, portrait_decl, portrait_helper, "portrait loader")

    portrait_tail = r'''    if (pick == PICK_XUAN && g_taoistAntagonistImage) {
        name = L"玄衡子";
        title = L"太上玄衡观";
        return g_taoistAntagonistImage;
    }
    return nullptr;
}'''
    portrait_tail_new = r'''    if (pick == PICK_XUAN && g_taoistAntagonistImage) {
        name = L"玄衡子";
        title = L"太上玄衡观";
        return g_taoistAntagonistImage;
    }

    Image* curated = nullptr;
    if (text.find(L"江照雪") != wstring::npos || text.find(L"战帖") != wstring::npos ||
        text.find(L"雪庭") != wstring::npos) {
        curated = LoadCuratedStoryArtImage(L"story_art\\characters\\frost_sword_heroine.jpg");
        if (curated) {
            name = text.find(L"江照雪") != wstring::npos ? L"江照雪" : L"雪庭剑修";
            title = L"霜雪问剑";
            return curated;
        }
    }
    if (text.find(L"灵芝") != wstring::npos || text.find(L"药铺") != wstring::npos ||
        text.find(L"杏林") != wstring::npos) {
        curated = LoadCuratedStoryArtImage(L"story_art\\characters\\herbalist_lingzhi.jpg");
        if (curated) {
            name = L"灵芝药师";
            title = L"杏林医修";
            return curated;
        }
    }
    if (text.find(L"草药园") != wstring::npos || text.find(L"药圃") != wstring::npos ||
        text.find(L"治愈") != wstring::npos) {
        curated = LoadCuratedStoryArtImage(L"story_art\\characters\\jade_healer.jpg");
        if (curated) {
            name = L"玉庭医修";
            title = L"草木回春";
            return curated;
        }
    }
    if (text.find(L"古琴") != wstring::npos || text.find(L"琴声") != wstring::npos ||
        text.find(L"琴修") != wstring::npos) {
        curated = LoadCuratedStoryArtImage(L"story_art\\characters\\moon_guqin_lady.jpg");
        if (curated) {
            name = L"月下琴修";
            title = L"听月琴心";
            return curated;
        }
    }
    if (text.find(L"符箓") != wstring::npos || text.find(L"符阵") != wstring::npos ||
        text.find(L"符阁") != wstring::npos) {
        curated = LoadCuratedStoryArtImage(L"story_art\\characters\\talisman_mistress.jpg");
        if (curated) {
            name = L"符阁女修";
            title = L"符箓执事";
            return curated;
        }
    }
    if (text.find(L"藏经阁") != wstring::npos || text.find(L"讲经") != wstring::npos ||
        text.find(L"经卷") != wstring::npos || text.find(L"课堂") != wstring::npos) {
        curated = LoadCuratedStoryArtImage(L"story_art\\characters\\scripture_lecturer.jpg");
        if (curated) {
            name = L"经阁讲师";
            title = L"藏经授业";
            return curated;
        }
    }
    if (text.find(L"月亭") != wstring::npos || text.find(L"宫亭") != wstring::npos ||
        text.find(L"月宫") != wstring::npos) {
        curated = LoadCuratedStoryArtImage(L"story_art\\characters\\moon_pavilion_lady.jpg");
        if (curated) {
            name = L"月亭女修";
            title = L"月华照影";
            return curated;
        }
    }
    if (text.find(L"剑宗") != wstring::npos || text.find(L"师姐") != wstring::npos ||
        text.find(L"试剑") != wstring::npos || text.find(L"剑修") != wstring::npos) {
        curated = LoadCuratedStoryArtImage(L"story_art\\characters\\qingyun_sword_heroine.jpg");
        if (curated) {
            name = L"青云剑修";
            title = L"山门问剑";
            return curated;
        }
    }
    return nullptr;
}'''
    text = replace_once(text, portrait_tail, portrait_tail_new, "generic portrait routing")

    draw_anchor = "// ==================== 绘制函数 ====================\nvoid OnPaint(HDC hdc, RECT& rect) {"
    scene_router = r'''Image* GetEventSceneImage(const Event* event) {
    if (!event) return nullptr;
    wstring text = event->title + L" " + event->description;

    if (text.find(L"轮回") != wstring::npos || text.find(L"转世") != wstring::npos ||
        text.find(L"祭坛") != wstring::npos || text.find(L"旧玉") != wstring::npos) {
        return LoadCuratedStoryArtImage(L"story_art\\scenes\\reincarnation_altar.jpg");
    }
    if (text.find(L"祖魂") != wstring::npos || text.find(L"前世") != wstring::npos ||
        text.find(L"魂殿") != wstring::npos || text.find(L"传承") != wstring::npos) {
        return LoadCuratedStoryArtImage(L"story_art\\scenes\\ancestor_soul_hall.jpg");
    }
    if (text.find(L"藏经") != wstring::npos || text.find(L"讲经") != wstring::npos ||
        text.find(L"课堂") != wstring::npos || text.find(L"经卷") != wstring::npos) {
        return LoadCuratedStoryArtImage(L"story_art\\scenes\\scripture_classroom.jpg");
    }
    if (text.find(L"古琴") != wstring::npos || text.find(L"琴声") != wstring::npos ||
        text.find(L"月亭") != wstring::npos) {
        return LoadCuratedStoryArtImage(L"story_art\\scenes\\moon_guqin_pavilion.jpg");
    }
    if (text.find(L"剑宗") != wstring::npos || text.find(L"试剑") != wstring::npos ||
        text.find(L"剑庭") != wstring::npos || text.find(L"演武") != wstring::npos ||
        text.find(L"山门") != wstring::npos) {
        return LoadCuratedStoryArtImage(L"story_art\\scenes\\qingyun_sword_court.jpg");
    }
    return nullptr;
}

// ==================== 绘制函数 ====================
void OnPaint(HDC hdc, RECT& rect) {'''
    text = replace_once(text, draw_anchor, scene_router, "scene router")

    background_old = r'''    // 背景
    if (g_bgImage) {
        graphics.DrawImage(g_bgImage, 0, 0, rect.right, rect.bottom);
    } else {
        LinearGradientBrush bgBrush(Point(0, 0), Point(0, rect.bottom),
            Color(255, 20, 20, 30), Color(255, 40, 40, 60));
        graphics.FillRectangle(&bgBrush, 0, 0, rect.right, rect.bottom);
    }'''
    background_new = r'''    // 背景 · V0_12_CURATED_STORY_ART_RUNTIME
    Image* activeBackground = g_bgImage;
    if (g_gameState == STATE_EVENT && g_currentEvent) {
        Image* eventScene = GetEventSceneImage(g_currentEvent);
        if (eventScene) activeBackground = eventScene;
    }
    if (activeBackground) {
        graphics.DrawImage(activeBackground, 0, 0, rect.right, rect.bottom);
    } else {
        LinearGradientBrush bgBrush(Point(0, 0), Point(0, rect.bottom),
            Color(255, 20, 20, 30), Color(255, 40, 40, 60));
        graphics.FillRectangle(&bgBrush, 0, 0, rect.right, rect.bottom);
    }'''
    text = replace_once(text, background_old, background_new, "active scene background")

    loaders_old = r'''    if (GetFileAttributesW(L"background.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_bgImage = Image::FromFile(L"background.jpg");
    } else if (GetFileAttributesW(L"background.png") != INVALID_FILE_ATTRIBUTES) {
        g_bgImage = Image::FromFile(L"background.png");
    }
    if (GetFileAttributesW(L"previews\\item_atlas_v4.png") != INVALID_FILE_ATTRIBUTES) {
        g_itemAtlasImage = Image::FromFile(L"previews\\item_atlas_v4.png");
    }
    if (GetFileAttributesW(L"characters\\taoist_antagonist.png") != INVALID_FILE_ATTRIBUTES) {
        g_taoistAntagonistImage = Image::FromFile(L"characters\\taoist_antagonist.png");
    }
    if (GetFileAttributesW(L"characters\\frost_crow.png") != INVALID_FILE_ATTRIBUTES) {
        g_frostCrowImage = Image::FromFile(L"characters\\frost_crow.png");
    }
    if (GetFileAttributesW(L"characters\\luo_ningshuang.png") != INVALID_FILE_ATTRIBUTES) {
        g_luoNingshuangImage = Image::FromFile(L"characters\\luo_ningshuang.png");
    }
    if (GetFileAttributesW(L"characters\\qingheng.png") != INVALID_FILE_ATTRIBUTES) {
        g_qinghengImage = Image::FromFile(L"characters\\qingheng.png");
    }
    if (GetFileAttributesW(L"characters\\protagonist.png") != INVALID_FILE_ATTRIBUTES) {
        g_protagonistImage = Image::FromFile(L"characters\\protagonist.png");
    }'''
    loaders_new = r'''    if (GetFileAttributesW(L"story_art\\scenes\\reincarnation_altar.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_bgImage = Image::FromFile(L"story_art\\scenes\\reincarnation_altar.jpg");
    } else if (GetFileAttributesW(L"background.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_bgImage = Image::FromFile(L"background.jpg");
    } else if (GetFileAttributesW(L"background.png") != INVALID_FILE_ATTRIBUTES) {
        g_bgImage = Image::FromFile(L"background.png");
    }
    if (GetFileAttributesW(L"previews\\item_atlas_v4.png") != INVALID_FILE_ATTRIBUTES) {
        g_itemAtlasImage = Image::FromFile(L"previews\\item_atlas_v4.png");
    }
    if (GetFileAttributesW(L"characters\\taoist_antagonist.png") != INVALID_FILE_ATTRIBUTES) {
        g_taoistAntagonistImage = Image::FromFile(L"characters\\taoist_antagonist.png");
    }
    if (GetFileAttributesW(L"story_art\\characters\\frost_sword_heroine.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_frostCrowImage = Image::FromFile(L"story_art\\characters\\frost_sword_heroine.jpg");
    } else if (GetFileAttributesW(L"characters\\frost_crow.png") != INVALID_FILE_ATTRIBUTES) {
        g_frostCrowImage = Image::FromFile(L"characters\\frost_crow.png");
    }
    if (GetFileAttributesW(L"story_art\\characters\\qingyun_sword_heroine.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_luoNingshuangImage = Image::FromFile(L"story_art\\characters\\qingyun_sword_heroine.jpg");
    } else if (GetFileAttributesW(L"characters\\luo_ningshuang.png") != INVALID_FILE_ATTRIBUTES) {
        g_luoNingshuangImage = Image::FromFile(L"characters\\luo_ningshuang.png");
    }
    if (GetFileAttributesW(L"story_art\\characters\\scripture_lecturer.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_qinghengImage = Image::FromFile(L"story_art\\characters\\scripture_lecturer.jpg");
    } else if (GetFileAttributesW(L"characters\\qingheng.png") != INVALID_FILE_ATTRIBUTES) {
        g_qinghengImage = Image::FromFile(L"characters\\qingheng.png");
    }
    if (GetFileAttributesW(L"story_art\\characters\\protagonist_hooded_close.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_protagonistImage = Image::FromFile(L"story_art\\characters\\protagonist_hooded_close.jpg");
    } else if (GetFileAttributesW(L"story_art\\characters\\protagonist_hooded_rain.jpg") != INVALID_FILE_ATTRIBUTES) {
        g_protagonistImage = Image::FromFile(L"story_art\\characters\\protagonist_hooded_rain.jpg");
    } else if (GetFileAttributesW(L"characters\\protagonist.png") != INVALID_FILE_ATTRIBUTES) {
        g_protagonistImage = Image::FromFile(L"characters\\protagonist.png");
    }'''
    text = replace_once(text, loaders_old, loaders_new, "WinMain curated loaders")
    return text


def main() -> int:
    text = SRC.read_text(encoding="utf-8")
    patched = patch_source(text)
    if patched != text:
        SRC.write_text(patched, encoding="utf-8")
        print("Applied v0.12 curated story-art runtime integration.")

    # Make the verified library available beside the executable for local builds.
    install_curated_story_art()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
