// 程序化生成系统 - 无限内容
#pragma once
#include <string>
#include <vector>
#include <random>
#include <sstream>

using namespace std;

// ==================== 名称生成器 ====================
class NameGenerator {
private:
    vector<wstring> prefixes = {
        L"青", L"天", L"玄", L"太", L"紫", L"金", L"银", L"碧",
        L"赤", L"白", L"黑", L"幽", L"圣", L"魔", L"仙", L"灵"
    };

    vector<wstring> middles = {
        L"云", L"霄", L"虚", L"玄", L"元", L"道", L"法", L"剑",
        L"丹", L"符", L"阵", L"器", L"灵", L"神", L"魂", L"体"
    };

    vector<wstring> suffixes = {
        L"宗", L"派", L"门", L"阁", L"殿", L"宫", L"楼", L"府",
        L"谷", L"岛", L"山", L"峰", L"洞", L"境", L"界", L"域"
    };

public:
    wstring GenerateSectName() {
        int p = rand() % prefixes.size();
        int m = rand() % middles.size();
        int s = rand() % suffixes.size();
        return prefixes[p] + middles[m] + suffixes[s];
    }

    wstring GeneratePersonName() {
        vector<wstring> surnames = {L"李", L"王", L"张", L"刘", L"陈", L"杨", L"黄", L"赵", L"周", L"吴"};
        vector<wstring> names = {
            L"云天", L"若雪", L"逍遥", L"无极", L"玄机", L"道一",
            L"天明", L"月华", L"星辰", L"风流", L"剑心", L"丹青"
        };

        return surnames[rand() % surnames.size()] + names[rand() % names.size()];
    }

    wstring GenerateTreasureName() {
        vector<wstring> adjectives = {L"古老的", L"神秘的", L"破损的", L"闪耀的", L"黑暗的"};
        vector<wstring> items = {L"玉简", L"法宝", L"灵器", L"仙器", L"神器"};

        return adjectives[rand() % adjectives.size()] + items[rand() % items.size()];
    }
};

// ==================== 宗门生成器 ====================
struct GeneratedSect {
    wstring name;
    wstring philosophy;  // 理念
    wstring specialty;   // 特长
    wstring lore;        // 背景故事
    int power;           // 实力 1-10

    GeneratedSect() : power(1) {}
};

class SectGenerator {
private:
    NameGenerator nameGen;

public:
    GeneratedSect Generate() {
        GeneratedSect sect;
        sect.name = nameGen.GenerateSectName();
        sect.power = 1 + rand() % 10;

        // 理念
        vector<wstring> philosophies = {
            L"正道", L"魔道", L"散修联盟", L"中立", L"隐世"
        };
        sect.philosophy = philosophies[rand() % philosophies.size()];

        // 特长
        vector<wstring> specialties = {
            L"剑修", L"丹道", L"阵法", L"炼器", L"符箓",
            L"体修", L"御兽", L"音律", L"幻术", L"空间"
        };
        sect.specialty = specialties[rand() % specialties.size()];

        // 生成背景故事
        sect.lore = GenerateLore(sect);

        return sect;
    }

private:
    wstring GenerateLore(GeneratedSect& sect) {
        wstringstream ss;
        ss << sect.name << L"创立于" << (1000 + rand() % 9000) << L"年前，";

        if (sect.philosophy == L"正道") {
            ss << L"以匡扶正义为己任，";
        } else if (sect.philosophy == L"魔道") {
            ss << L"追求力量至上，不择手段，";
        } else {
            ss << L"超然物外，独善其身，";
        }

        ss << L"尤其擅长" << sect.specialty << L"。";

        return ss.str();
    }
};

// ==================== 地点生成器 ====================
struct GeneratedLocation {
    wstring name;
    wstring type;        // 类型
    int dangerLevel;     // 危险度 1-10
    wstring description;

    GeneratedLocation() : dangerLevel(1) {}
};

class LocationGenerator {
private:
    NameGenerator nameGen;

public:
    GeneratedLocation Generate() {
        GeneratedLocation loc;
        loc.dangerLevel = 1 + rand() % 10;

        // 类型
        vector<wstring> types = {
            L"洞府", L"秘境", L"遗迹", L"禁地", L"福地",
            L"魔窟", L"仙府", L"古墓", L"神殿", L"虚空"
        };
        loc.type = types[rand() % types.size()];

        // 名称
        vector<wstring> adjectives = {
            L"幽暗", L"古老", L"神秘", L"危险", L"祥和",
            L"诡异", L"混沌", L"虚无", L"永恒", L"时光"
        };
        loc.name = adjectives[rand() % adjectives.size()] + loc.type;

        // 描述
        loc.description = GenerateLocationDesc(loc);

        return loc;
    }

private:
    wstring GenerateLocationDesc(GeneratedLocation& loc) {
        wstringstream ss;
        ss << L"这是一处" << loc.name << L"，";

        if (loc.dangerLevel > 7) {
            ss << L"充满了恐怖的气息，一般修士不敢靠近。";
        } else if (loc.dangerLevel > 4) {
            ss << L"有一定风险，但也可能蕴含机缘。";
        } else {
            ss << L"相对安全，适合修炼。";
        }

        return ss.str();
    }
};

// ==================== 功法生成器 ====================
struct GeneratedTechnique {
    wstring name;
    wstring element;     // 五行属性
    int power;           // 威力
    wstring description;

    GeneratedTechnique() : power(1) {}
};

class TechniqueGenerator {
public:
    GeneratedTechnique Generate(int realm) {
        GeneratedTechnique tech;
        tech.power = 10 + realm * 10 + rand() % 20;

        // 五行属性
        vector<wstring> elements = {L"火", L"水", L"木", L"金", L"土"};
        tech.element = elements[rand() % elements.size()];

        // 名称
        vector<wstring> prefixes = {L"天", L"地", L"玄", L"黄", L"太", L"上"};
        vector<wstring> middles = {L"罡", L"煞", L"元", L"真", L"灵", L"神"};
        vector<wstring> suffixes = {L"诀", L"经", L"典", L"法", L"术", L"功"};

        tech.name = prefixes[rand() % prefixes.size()] +
                   tech.element +
                   middles[rand() % middles.size()] +
                   suffixes[rand() % suffixes.size()];

        // 描述
        tech.description = L"传说中的" + tech.element + L"系功法，威力强大。";

        return tech;
    }
};

// ==================== 完整世界生成器 ====================
class ProceduralWorldGenerator {
private:
    SectGenerator sectGen;
    LocationGenerator locGen;
    TechniqueGenerator techGen;
    NameGenerator nameGen;

public:
    // 生成初始世界
    struct WorldData {
        vector<GeneratedSect> sects;
        vector<GeneratedLocation> locations;
        vector<wstring> npcNames;
    };

    WorldData GenerateWorld() {
        WorldData world;

        // 生成5-10个宗门
        int sectCount = 5 + rand() % 6;
        for (int i = 0; i < sectCount; i++) {
            world.sects.push_back(sectGen.Generate());
        }

        // 生成10-20个地点
        int locCount = 10 + rand() % 11;
        for (int i = 0; i < locCount; i++) {
            world.locations.push_back(locGen.Generate());
        }

        // 生成20个NPC名字
        for (int i = 0; i < 20; i++) {
            world.npcNames.push_back(nameGen.GeneratePersonName());
        }

        return world;
    }

    // 动态生成新的宗门（世界演化）
    GeneratedSect GenerateNewSect() {
        return sectGen.Generate();
    }

    // 动态生成新的地点
    GeneratedLocation GenerateNewLocation() {
        return locGen.Generate();
    }

    // 生成功法
    GeneratedTechnique GenerateTechnique(int realm) {
        return techGen.Generate(realm);
    }

    // 生成宝物
    wstring GenerateTreasure() {
        return nameGen.GenerateTreasureName();
    }
};
