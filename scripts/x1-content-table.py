#!/usr/bin/env python3
"""Regenerate docs/design/nana-x1-content.md from game/data/x1/*.json.

The JSON files are the source of truth; run this after changing them so the
readable table stays in sync:  python3 -B scripts/x1-content-table.py
"""

import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
DATA = PROJECT / 'game/data/x1'
OUT = PROJECT / 'docs/design/nana-x1-content.md'


def load(name):
    return json.loads((DATA / (name + '.json')).read_text(encoding='utf-8'))


def main():
    cards = load('cards')
    enemies = load('enemies')
    regions = load('regions')
    habits = load('habits')
    items = load('items')
    unlocks = load('unlocks')['conditions']
    events = load('events')['events']
    night = load('night_levels')
    unlock_by_target = {c['unlock']: c['desc'] for c in unlocks}
    lines = [
        '# 奈奈夜巡 X1：內容表（由資料檔產生）',
        '',
        '**自動產生，請勿手改。** 來源是 `game/data/x1/*.json`；改完資料後執行 `python3 -B scripts/x1-content-table.py` 重新產生。'
        '設計理由見 [X1 提案](nana-pounce-redesign-proposal-x1.md)，調整方法見 [調參指南](../development/x1-tuning-guide.md)。',
        '',
        '## 三種習性',
        '',
        '| 習性 | 效果 | 偏向的卡 |',
        '| --- | --- | --- |',
    ]
    for habit in habits.values():
        bias = '、'.join(cards['categories'][c]['name'] for c in habit['bias'])
        lines.append('| %s | %s | %s |' % (habit['title'], habit['desc'], bias))
    lines += ['', '## 本能卡（48 張）', '',
              '每張最多 3 級；卡片格 6 格。「起始」可直接抽到；其他要先達成解鎖條件。', '']
    for key, category in cards['categories'].items():
        lines += ['### %s' % category['name'], '', '| 卡 | 稀有度 | Lv.1 / Lv.2 / Lv.3 | 取得 |', '| --- | --- | --- | --- |']
        for card in cards['cards']:
            if card['category'] != key:
                continue
            rarity = '稀有' if card['rarity'] == 'rare' else '普通'
            source = '起始' if card['starter'] else unlock_by_target.get(card['id'], '？')
            lines.append('| %s %s | %s | %s | %s |' % (card['id'], card['name'], rarity, ' / '.join(card['desc']), source))
        lines.append('')
    lines += ['## 進化（8 組）', '', '第一張卡練到 Lv.3、並持有第二張卡時，下次升級必定出現；進化會取代第一張卡的格子。', '',
              '| 進化 | 需要 | 效果 |', '| --- | --- | --- |']
    names = {c['id']: c['name'] for c in cards['cards']}
    for evo in cards['evolutions']:
        lines.append('| %s %s | %s Lv.3 ＋ %s | %s |' % (evo['id'], evo['name'], names[evo['requires'][0]], names[evo['requires'][1]], evo['desc'][0]))
    lines += ['', '## 寶物（12 件）', '', '| 寶物 | 格位 | 效果 | 取得 |', '| --- | --- | --- | --- |']
    for item_id, item in items.items():
        slot = '習慣・%s' % habits[item['habit']]['name'] if item['slot'] == 'habit' else '隨身小物'
        source = {'starter': '新存檔就有', 'chest': '獵物巢／守關寶箱'}.get(item['source'], unlock_by_target.get(item_id, '？'))
        lines.append('| %s %s | %s | %s | %s |' % (item_id, item['name'], slot, item['desc'], source))
    lines += ['', '## 敵人', '', '| 敵人 | 角色 | 生命 | 移速 | 說明數值 |', '| --- | --- | --- | --- | --- |']
    roles = {'fodder': '雜兵', 'hound': '獵犬', 'special': '特殊', 'elite': '精英', 'boss': '守關'}
    for enemy_id, enemy in enemies.items():
        extra = []
        for key in ('damage', 'contact', 'windup', 'windup1', 'trigger'):
            if key in enemy:
                extra.append('%s %s' % (key, enemy[key]))
        lines.append('| %s %s | %s | %s | %s | %s |' % (enemy_id, enemy['name'], roles[enemy['role']], enemy['hp'], enemy['speed'], '、'.join(extra)))
    lines += ['', '生命為基準值；非守關敵人另乘區域與層數倍率（見 `spawns.json` 與 `regions.json`）。', '',
              '## 三個區域', '', '| 區域 | 開放條件 | 障礙 | 特殊敵 | 精英 | 守關 | 生命／傷害倍率 |', '| --- | --- | --- | --- | --- | --- | --- |']
    for region_id, region in regions.items():
        requires = regions[region['requires']]['name'] + ' 通關' if region['requires'] else '一開始'
        lines.append('| %s | %s | %d 個 | %s | %s | %s %s | ×%s／×%s |' % (
            region['name'], requires, len(region['obstacles']), '、'.join(enemies[e]['name'] for e in region['specials']),
            '、'.join(enemies[e]['name'] for e in region['elites']), region['boss'], enemies[region['boss']]['name'],
            region['hp_mult'], region['damage_mult']))
    lines += ['', '## 夜深 1–8（逐層累加，預警時間不縮短）', '']
    for level in night['levels']:
        lines.append('%d. %s' % (level['level'], level['desc']))
    lines += ['', '## 月光事件', '', '| 事件 | 區域 | 選項 |', '| --- | --- | --- |']
    for event in events:
        where = '、'.join(regions[r]['name'] for r in event['regions']) if event['regions'] else '全部'
        lines.append('| %s %s | %s | %s |' % (event['id'], event['title'], where, '／'.join(o['label'] for o in event['options'])))
    lines += ['', '## 解鎖條件（30 條）', '', '| 條件 | 解鎖 |', '| --- | --- |']
    for condition in unlocks:
        target = condition['unlock']
        name = names.get(target) or items.get(target, {}).get('name', target)
        lines.append('| %s | %s %s |' % (condition['desc'], target, name))
    OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('wrote', OUT.relative_to(PROJECT))


if __name__ == '__main__':
    main()
