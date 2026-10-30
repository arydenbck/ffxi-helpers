--[[
Copyright © 2018, from20020516
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of Trusts nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL from20020516 BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
_addon.name='Trusts'
_addon.author='from20020516'
_addon.version='1.3'
_addon.commands={'trusts','tru'}

config = require('config')
math = require('math')
math.randomseed(os.clock())
require('logger')
res = require('resources')
texts = require('texts')

windower.register_event('load',function()
    defaults = {
        auto=true,
        language=windower.ffxi.get_info().language,
        sets={
            ['default']={
                English={
                    ['1']='Valaineral',
                    ['2']='Mihli Aliapoh',
                    ['3']='Tenzen',
                    ['4']='Adelheid',
                    ['5']='Joachim'},
                Japanese={
                    ['1']='ヴァレンラール',
                    ['2']='ミリ・アリアポー',
                    ['3']='テンゼン',
                    ['4']='アーデルハイト',
                    ['5']='ヨアヒム'}}[windower.ffxi.get_info().language]},
        wait={
            ['aftercast']=3,
            ['retr']=1.25,
            ['retrall']=3,
            ['fail']=6},
        box={pos={x=60,y=200}, bg={alpha=210,red=0,green=0,blue=0}, text={size=11,font='Consolas',stroke={width=1,alpha=180}}, padding=6},
        alert={pos={x=60,y=110}, bg={alpha=235,red=60,green=0,blue=0}, text={size=13,font='Consolas',stroke={width=1,alpha=180}}, padding=8},
        alert_seconds=10,
        box_seconds=0,      -- auto-hide the cipher box after N seconds (0 = stay until hidden)
        guard='block',      -- NPC shop guard: block | warn | off
        zone_check=true,    -- refuse to summon in areas where trusts are not allowed
        learned_zones={},   -- zones you flagged with //tru block (keys 'z<zone id>')
    }
    settings = config.load(defaults)
    lang = string.lower(settings.language)
    player = windower.ffxi.get_player()
    trusts = build_trusts()
end)

windower.register_event('login',function()
    player = windower.ffxi.get_player()
end)

windower.register_event('addon command',function(...)
    cmd = {...}
    if cmd[1] == 'help' then
        show_help()
    elseif cmd[1] == 'save' then
        save_set(cmd[2])
    elseif cmd[1] == 'check' then
        check_learned()
    elseif cmd[1] == 'list' then
        list_sets()
    elseif cmd[1] == 'force' then
        call_set(cmd[2] or 'default', true)
    elseif cmd[1] == 'block' then
        learn_zone(true)
    elseif cmd[1] == 'unblock' then
        learn_zone(false)
    elseif cmd[1] == 'zone' then
        show_zone()
    elseif cmd[1] == 'guard' then
        set_guard(cmd[2])
    elseif cmd[1] == 'shop' then
        show_shop()
    elseif cmd[1] == 'hide' then
        box_hide()
    elseif cmd[1] == 'box' then
        box_command(cmd[2], cmd[3])
    elseif cmd[1] == 'sniff' then
        sniff(cmd[2])
    else
        call_set(cmd[1] or 'default')
    end
end)

function show_help()
    local chat = windower.add_to_chat
    local color = string.color
    chat(1,'Trusts - Command List:')
    chat(207,'//tru '..color('save <setname>',166,160)..' --Save trusts in current party.')
    chat(207,'//tru '..color('<setname>',166,160)..' --Calls trusts you saved.')
    chat(207,'//tru '..color('list',166,160)..' --Lists your saved sets.')
    chat(207,'//tru '..color('random',166,160)..' --What\'s your fortune today?')
    chat(207,'//tru '..color('check',166,160)..' --List of unlearned trusts (with the cipher to buy). gotta catch \'em all!')
    chat(207,'//tru '..color('shop',166,160)..' --Re-list the open/last NPC shop, marking trust ciphers you already know.')
    chat(207,'//tru '..color('sniff start|stop',166,160)..' --Record the packets of an NPC menu to data/sniff_*.txt (for debugging).')
    chat(207,'//tru '..color('guard <block|warn|off>',166,160)..' --What to do when you try to buy a cipher you already have.')
    chat(207,'//tru '..color('zone',166,160)..' --Can trusts be summoned here? | '..color('block',166,160)..' / '..color('unblock',166,160)..' remember/forget this zone as restricted.')
    chat(207,'//tru '..color('force <setname>',166,160)..' --Summon even if the area/party check says no.')
end

function save_set(set)
    if not set then
        windower.add_to_chat(207, string.color('No set name provided.', 167)..' //tru '..string.color('save <setname>', 166, 160)..' --Save trusts in current party.')
        return
    end

    settings.sets[set] = {}
    local trust_ind = 0
    local get_party = windower.ffxi.get_party()
    for i = 1, 5 do
        local trust = get_party['p'..i]
        if trust and trust.mob.spawn_type == 14 then
            trust_ind = trust_ind + 1
            settings.sets[set][tostring(trust_ind)] = trusts:with('models', trust.mob.models[1])[lang]
        end
    end
    settings:save('all')
    log('Set "'..set..'" saved.')
end

function list_sets()
    local chat = windower.add_to_chat
    settings = config.load()
    chat(1, 'Trusts - Saved sets:')

    for set, _ in pairs(settings.sets) do
        if set ~= 'default' then
            chat(207, set)
        end
    end
end

function check_lang(entity)
    return {japanese=entity.japanese,english=entity.english}[lang];
end

function check_limit()
    for i,v in pairs(windower.ffxi.get_key_items()) do
        --Trust permit,Rhapsody in..
        limit = S{2497,2499,2501}[v] and 3 or v==2884 and 4 or v==2886 and 5 or limit or 0
    end
    return limit;
end

function call_trust()
    if #queue > 0 then
        cast_token = (cast_token or 0) + 1
        cast_started = false
        local token, entity = cast_token, queue[1]
        windower.chat.input('/ma "'..windower.to_shift_jis(check_lang(entity))..'" <me>')
        coroutine.schedule(function() cast_watch(token, entity) end, settings.wait.fail)
    end
end

-- If a cast never starts (restricted area, party rules, silence...) stop instead of stalling silently.
function cast_watch(token, entity)
    if token ~= cast_token or cast_started or not queue or queue[1] ~= entity then return end
    queue = {}
    windower.add_to_chat(207, string.color(check_lang(entity)..' could not be summoned', 167)..' - the cast never started. Restricted area or party rules? Use //tru zone to check, //tru block to remember this zone.')
end

function check_exist()
    local party = {} --include only trusts. --['name']=models
    local party_ind = {} -- index of trust's name in current party. {'name1','name2',...,'name5'}
    local get_party = windower.ffxi.get_party()
    for i=1,5 do
        local member = get_party['p'..i]
        if member and member.mob then
            if member.mob.spawn_type == 14 then
                party[member.name] = member.mob.models[1]
                table.insert(party_ind,member.name)
            end
        end
    end
    return {party,party_ind};
end

function call_set(set, force)
    queue = {} --trusts to be cast.
    if not force then
        local reason = summon_blocked()
        if reason then
            windower.add_to_chat(207, string.color('Trusts can\'t be summoned: ', 167)..reason..' (//tru force '..(set or 'default')..' to try anyway)')
            return
        end
    end
    settings = config.load()
    local party,party_ind = unpack(check_exist())
    local limit = check_limit() --upper limit # of calls trust in current player.
    local time = os.clock() --window open
    local get_spells = windower.ffxi.get_spells()
    local get_spell_recasts = windower.ffxi.get_spell_recasts()

    if set == 'random' then
        local checked = {}
        local others = windower.ffxi.get_party().party1_count - #party_ind - 1 --# of human in party exept <me>.

        if limit == #party_ind then
            windower.chat.input('/retr all')
            calls = limit
            coroutine.sleep(settings.wait.retrall)
        else
            calls = limit - #party_ind - others
        end

        repeat
            local index = trusts[math.random(1,#trusts)]
            if not table.find(checked,index.name) then
                table.insert(checked,index.name)
                if get_spells[index.id] and get_spell_recasts[index.id] == 0 then
                    table.insert(queue,index)
                end
            end
        until #queue >= calls or #checked >= unique_trust_names() --every unique name tried

    elseif settings.sets[set] then
        retr = {unpack(party_ind)}
        for i=1,limit do
            if settings.sets[set][tostring(i)] then
                local entity = trusts:with(lang,settings.sets[set][tostring(i)])
                if not party[entity.name]
                or party[entity.name] ~= entity.models then
                    if get_spell_recasts[entity.id] == 0 then
                        if get_spells[entity.id] then
                            table.insert(queue,entity)
                        else
                            table.remove(retr,table.find(retr,party_ind[i]))
                            windower.add_to_chat(207,'You aren\'t trusted by '..entity.english..'.')
                        end
                    else
                        table.remove(retr,table.find(retr,party_ind[i]))
                        local recast = math.floor(get_spell_recasts[entity.id] / 6) / 10
                        log(entity.english..' needs '..recast..' secs break.')
                    end
                else
                    table.remove(retr,table.find(retr,entity.name))
                    if settings.auto then
                        log(entity.english..' already exists.')
                    end
                end
            end
        end
        for index,name in pairs(retr) do
            if #retr == #party_ind then
                windower.chat.input('/retr all')
                coroutine.sleep(settings.wait.retrall)
                break;
            else
                windower.chat.input('/retr '..name)
                coroutine.sleep(settings.wait.retr)
            end
        end
    else
        windower.add_to_chat(207,'Unknown set name '..(set or ''))
    end
    --if /retr then wait at least 3secs.
    local delay = (limit - #party_ind) == 0 and math.max(0,settings.wait.retrall + time - os.clock()) or 0
    coroutine.schedule(call_trust,delay)
end

windower.register_event('action', function(act)
    if player and act.actor_id == player.id and act.category == 8 and act.param == 24931 then
        cast_started = true
    end
    if settings.auto and act.actor_id == player.id and queue and #queue > 0 then
        if act.category == 4 and act.param == table.remove(queue,1).id then
            coroutine.schedule(call_trust,settings.wait.aftercast)
        elseif act.category == 8 and act.param == 28787 and act.targets[1].actions[1].param == queue[1].id then
            coroutine.schedule(call_trust,settings.wait.aftercast)
        end
    end
end)

function check_learned()
    local missing = 0
    local get_spells = windower.ffxi.get_spells()
    build_cipher_map()
    for i,value in ipairs(trusts) do
        if get_spells[value.id] == false and not value.english:endswith('(UC)') then
            missing = missing + 1
            local cipher = cipher_for[value.id]
            log(check_lang(value)..(cipher and ('  [buy: '..cipher..']') or ''))
        end
    end
    log('You haven\'t trusted yet from '..missing..' trusts.')
end

trusts_static = T{
    [1]={id=896,japanese="シャントット",english="Shantotto",name="Shantotto",models=3000},
    [2]={id=897,japanese="ナジ",english="Naji",name="Naji",models=3001},
    [3]={id=898,japanese="クピピ",english="Kupipi",name="Kupipi",models=3002},
    [4]={id=899,japanese="エグセニミル",english="Excenmille",name="Excenmille",models=3003},
    [5]={id=900,japanese="アヤメ",english="Ayame",name="Ayame",models=3004},
    [6]={id=901,japanese="ナナー・ミーゴ",english="Nanaa Mihgo",name="NanaaMihgo",models=3005},
    [7]={id=902,japanese="クリルラ",english="Curilla",name="Curilla",models=3006},
    [8]={id=903,japanese="フォルカー",english="Volker",name="Volker",models=3007},
    [9]={id=904,japanese="アジドマルジド",english="Ajido-Marujido",name="Ajido-Marujido",models=3008},
    [10]={id=905,japanese="トリオン",english="Trion",name="Trion",models=3009},
    [11]={id=906,japanese="ザイド",english="Zeid",name="Zeid",models=3010},
    [12]={id=907,japanese="ライオン",english="Lion",name="Lion",models=3011},
    [13]={id=908,japanese="テンゼン",english="Tenzen",name="Tenzen",models=3012},
    [14]={id=909,japanese="ミリ・アリアポー",english="Mihli Aliapoh",name="MihliAliapoh",models=3013},
    [15]={id=910,japanese="ヴァレンラール",english="Valaineral",name="Valaineral",models=3014},
    [16]={id=911,japanese="ヨアヒム",english="Joachim",name="Joachim",models=3015},
    [17]={id=912,japanese="ナジャ・サラヒム",english="Naja Salaheem",name="NajaSalaheem",models=3016},
    [18]={id=913,japanese="プリッシュ",english="Prishe",name="Prishe",models=3017},
    [19]={id=914,japanese="ウルミア",english="Ulmia",name="Ulmia",models=3018},
    [20]={id=915,japanese="スカリーZ",english="Shikaree Z",name="ShikareeZ",models=3019},
    [21]={id=916,japanese="チェルキキ",english="Cherukiki",name="Cherukiki",models=3020},
    [22]={id=917,japanese="アイアンイーター",english="Iron Eater",name="IronEater",models=3021},
    [23]={id=918,japanese="ゲッショー",english="Gessho",name="Gessho",models=3022},
    [24]={id=919,japanese="ガダラル",english="Gadalar",name="Gadalar",models=3023},
    [25]={id=920,japanese="ライニマード",english="Rainemard",name="Rainemard",models=3024},
    [26]={id=921,japanese="イングリッド",english="Ingrid",name="Ingrid",models=3025},
    [27]={id=922,japanese="レコ・ハボッカ",english="Lehko Habhoka",name="LehkoHabhoka",models=3026},
    [28]={id=923,japanese="ナシュメラ",english="Nashmeira",name="Nashmeira",models=3027},
    [29]={id=924,japanese="ザザーグ",english="Zazarg",name="Zazarg",models=3028},
    [30]={id=925,japanese="アヴゼン",english="Ovjang",name="Ovjang",models=3029},
    [31]={id=926,japanese="メネジン",english="Mnejing",name="Mnejing",models=3030},
    [32]={id=927,japanese="サクラ",english="Sakura",name="Sakura",models=3031},
    [33]={id=928,japanese="ルザフ",english="Luzaf",name="Luzaf",models=3032},
    [34]={id=929,japanese="ナジュリス",english="Najelith",name="Najelith",models=3033},
    [35]={id=930,japanese="アルド",english="Aldo",name="Aldo",models=3034},
    [36]={id=931,japanese="モーグリ",english="Moogle",name="Moogle",models=3035},
    [37]={id=932,japanese="ファブリニクス",english="Fablinix",name="Fablinix",models=3036},
    [38]={id=933,japanese="マート",english="Maat",name="Maat",models=3037},
    [39]={id=934,japanese="D.シャントット",english="D. Shantotto",name="D.Shantotto",models=3038},
    [40]={id=935,japanese="星の神子",english="Star Sibyl",name="StarSibyl",models=3039},
    [41]={id=936,japanese="カラハバルハ",english="Karaha-Baruha",name="Karaha-Baruha",models=3040},
    [42]={id=937,japanese="シド",english="Cid",name="Cid",models=3041},
    [43]={id=938,japanese="ギルガメッシュ",english="Gilgamesh",name="Gilgamesh",models=3042},
    [44]={id=939,japanese="アレヴァト",english="Areuhat",name="Areuhat",models=3043},
    [45]={id=940,japanese="セミ・ラフィーナ",english="Semih Lafihna",name="SemihLafihna",models=3044},
    [46]={id=941,japanese="エリヴィラ",english="Elivira",name="Elivira",models=3045},
    [47]={id=942,japanese="ノユリ",english="Noillurie",name="Noillurie",models=3046},
    [48]={id=943,japanese="ルー・マカラッカ",english="Lhu Mhakaracca",name="LhuMhakaracca",models=3047},
    [49]={id=944,japanese="フェリアスコフィン",english="Ferreous Coffin",name="FerreousCoffin",models=3048},
    [50]={id=945,japanese="リリゼット",english="Lilisette",name="Lilisette",models=3049},
    [51]={id=946,japanese="ミュモル",english="Mumor",name="Mumor",models=3050},
    [52]={id=947,japanese="ウカ・トトゥリン",english="Uka Totlihn",name="UkaTotlihn",models=3051},
    [53]={id=948,japanese="クララ",english="Klara",name="Klara",models=3053},
    [54]={id=949,japanese="ロマー・ミーゴ",english="Romaa Mihgo",name="RomaaMihgo",models=3054},
    [55]={id=950,japanese="クイン・ハスデンナ",english="Kuyin Hathdenna",name="KuyinHathdenna",models=3055},
    [56]={id=951,japanese="ラーアル",english="Rahal",name="Rahal",models=3056},
    [57]={id=952,japanese="コルモル",english="Koru-Moru",name="Koru-Moru",models=3057},
    [58]={id=953,japanese="ピエージェ(UC)",english="Pieuje (UC)",name="Pieuje",models=3058},
    [59]={id=954,japanese="I.シールド(UC)",english="I. Shield (UC)",name="InvincibleShld",models=3060},
    [60]={id=955,japanese="アプルル(UC)",english="Apururu (UC)",name="Apururu",models=3061},
    [61]={id=956,japanese="ジャコ(UC)",english="Jakoh (UC)",name="JakohWahcondalo",models=3062},
    [62]={id=957,japanese="フラヴィリア(UC)",english="Flaviria (UC)",name="Flaviria",models=3059},
    [63]={id=958,japanese="ウェイレア",english="Babban",name="Babban",models=3067},
    [64]={id=959,japanese="アベンツィオ",english="Abenzio",name="Abenzio",models=3068},
    [65]={id=960,japanese="ルガジーン",english="Rughadjeen",name="Rughadjeen",models=3069},
    [66]={id=961,japanese="クッキーチェブキー",english="Kukki-Chebukki",name="Kukki-Chebukki",models=3070},
    [67]={id=962,japanese="マルグレート",english="Margret",name="Margret",models=3071},
    [68]={id=963,japanese="チャチャルン",english="Chacharoon",name="Chacharoon",models=3072},
    [69]={id=964,japanese="レイ・ランガヴォ",english="Lhe Lhangavo",name="LheLhangavo",models=3073},
    [70]={id=965,japanese="アシェラ",english="Arciela",name="Arciela",models=3074},
    [71]={id=966,japanese="マヤコフ",english="Mayakov",name="Mayakov",models=3075},
    [72]={id=967,japanese="クルタダ",english="Qultada",name="Qultada",models=3076},
    [73]={id=968,japanese="アーデルハイト",english="Adelheid",name="Adelheid",models=3077},
    [74]={id=969,japanese="アムチュチュ",english="Amchuchu",name="Amchuchu",models=3078},
    [75]={id=970,japanese="ブリジッド",english="Brygid",name="Brygid",models=3079},
    [76]={id=971,japanese="ミルドリオン",english="Mildaurion",name="Mildaurion",models=3080},
    [77]={id=972,japanese="ハルヴァー",english="Halver",name="Halver",models=3087},
    [78]={id=973,japanese="ロンジェルツ",english="Rongelouts",name="Rongelouts",models=3088},
    [79]={id=974,japanese="レオノアーヌ",english="Leonoyne",name="Leonoyne",models=3089},
    [80]={id=975,japanese="マクシミリアン",english="Maximilian",name="Maximilian",models=3090},
    [81]={id=976,japanese="カイルパイル",english="Kayeel-Payeel",name="Kayeel-Payeel",models=3091},
    [82]={id=977,japanese="ロベルアクベル",english="Robel-Akbel",name="Robel-Akbel",models=3092},
    [83]={id=978,japanese="クポフリート",english="Kupofried",name="Kupofried",models=3093},
    [84]={id=979,japanese="セルテウス",english="Selh\'teus",name="Selh\'teus",models=3094},
    [85]={id=980,japanese="ヨランオラン(UC)",english="Yoran-Oran (UC)",name="Yoran-Oran",models=3095},
    [86]={id=981,japanese="シルヴィ(UC)",english="Sylvie (UC)",name="Sylvie",models=3096},
    [87]={id=982,japanese="アブクーバ",english="Abquhbah",name="Abquhbah",models=3098},
    [88]={id=983,japanese="バラモア",english="Balamor",name="Balamor",models=3099},
    [89]={id=984,japanese="オーグスト",english="August",name="August",models=3100},
    [90]={id=985,japanese="ロスレーシャ",english="Rosulatia",name="Rosulatia",models=3101},
    [91]={id=986,japanese="テオドール",english="Teodor",name="Teodor",models=3103},
    [92]={id=987,japanese="ウルゴア",english="Ullegore",name="Ullegore",models=3105},
    [93]={id=988,japanese="マッキーチェブキー",english="Makki-Chebukki",name="Makki-Chebukki",models=3106},
    [94]={id=989,japanese="キング・オブ・ハーツ",english="King of Hearts",name="KingOfHearts",models=3107},
    [95]={id=990,japanese="モリマー",english="Morimar",name="Morimar",models=3108},
    [96]={id=991,japanese="ダラクァルン",english="Darrcuiln",name="Darrcuiln",models=3109},
    [97]={id=992,japanese="アークHM",english="AAHM",name="ArkHM",models=3113},
    [98]={id=993,japanese="アークEV",english="AAEV",name="ArkEV",models=3114},
    [99]={id=994,japanese="アークMR",english="AAMR",name="ArkMR",models=3115},
    [100]={id=995,japanese="アークTT",english="AATT",name="ArkTT",models=3116},
    [101]={id=996,japanese="アークGK",english="AAGK",name="ArkGK",models=3117},
    [102]={id=997,japanese="イロハ",english="Iroha",name="Iroha",models=3111},
    [103]={id=998,japanese="ユグナス",english="Ygnas",name="Ygnas",models=3118},
    [104]={id=1004,japanese="エグセニミルII",english="Excenmille [S]",name="Excenmille",models=3052},
    [105]={id=1005,japanese="アヤメ(UC)",english="Ayame (UC)",name="Ayame",models=3063},
    [106]={id=1006,japanese="マート(UC)",english="Maat (UC)",name="Maat",models=3064}, --expected models
    [107]={id=1007,japanese="アルド(UC)",english="Aldo (UC)",name="Aldo",models=3065}, --expected models
    [108]={id=1008,japanese="ナジャ(UC)",english="Naja (UC)",name="NajaSalaheem",models=3066},
    [109]={id=1009,japanese="ライオンII",english="Lion II",name="Lion",models=3081},
    [110]={id=1010,japanese="ザイドII",english="Zeid II",name="Zeid",models=3086},
    [111]={id=1011,japanese="プリッシュII",english="Prishe II",name="Prishe",models=3082},
    [112]={id=1012,japanese="ナシュメラII",english="Nashmeira II",name="Nashmeira",models=3083},
    [113]={id=1013,japanese="リリゼットII",english="Lilisette II",name="Lilisette",models=3084},
    [114]={id=1014,japanese="テンゼンII",english="Tenzen II",name="Tenzen",models=3097},
    [115]={id=1015,japanese="ミュモルII",english="Mumor II",name="Mumor",models=3104},
    [116]={id=1016,japanese="イングリッドII",english="Ingrid II",name="Ingrid",models=3102},
    [117]={id=1017,japanese="アシェラII",english="Arciela II",name="Arciela",models=3085},
    [118]={id=1018,japanese="イロハII",english="Iroha II",name="Iroha",models=3112},
    [119]={id=1019,japanese="シャントットII",english="Shantotto II",name="Shantotto",models=3110},
    [120]={id=1002,japanese="コーネリア",english="Cornelia",name="Cornelia",models=3119}, --goodbye, my love
    [121]={id=999,japanese="モンブロー",english="Monberaux",name="Monberaux",models=3120},
    [122]={id=1003,japanese="マツイP",english="Matsui-P",name="Matsui-P",models=3121},
}


--------------------------------------------------------------------------------------------------
-- v1.3 additions
--------------------------------------------------------------------------------------------------

-- 1) Trust list: built from the game resources (every Trust spell Windower knows about), so new
--    trusts appear after a resources update. trusts_static above is only a fallback for ids
--    the resources do not have yet.
function build_trusts()
    local list = T{}
    local seen = {}
    for id, spell in pairs(res.spells) do
        if spell.type == 'Trust' then
            table.insert(list, {id=id, japanese=spell.ja, english=spell.en, name=spell.party_name or spell.en, models=spell.model})
            seen[id] = true
        end
    end
    for _, t in ipairs(trusts_static) do
        if not seen[t.id] then table.insert(list, t) end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function unique_trust_names()
    local names, n = {}, 0
    for _, t in ipairs(trusts) do
        if not names[t.name] then names[t.name] = true; n = n + 1 end
    end
    return n
end

-- 2) Areas where trusts can not be summoned.
-- Known restricted content (game notes / BG-Wiki): cities, Mog House, Dynamis, Limbus, Salvage,
-- Assault, Nyzul. Not every restricted zone is on this list, so the check is only a warning that
-- //tru force overrides, and //tru block remembers a zone you found out the hard way.
blocked_zone_names = S{
    "Northern San d'Oria","Southern San d'Oria","Port San d'Oria","Chateau d'Oraguille",
    "Bastok Mines","Bastok Markets","Port Bastok","Metalworks",
    "Windurst Waters","Windurst Walls","Port Windurst","Windurst Woods","Heavens Tower",
    "Ru'Lude Gardens","Upper Jeuno","Lower Jeuno","Port Jeuno",
    "Selbina","Mhaura","Kazham","Norg","Rabao",
    "Aht Urhgan Whitegate","Al Zahbi","Nashmau",
    "Western Adoulin","Eastern Adoulin","Celennia Memorial Library","Silver Knife",
    "Temenos","Apollyon",
    "Ilrusi Atoll","Periqia","Lebros Cavern","Mamool Ja Training Grounds","Leujaoam Sanctum",
    "Nyzul Isle","Zhayolm Remnants","Arrapago Remnants","Bhaflau Remnants","Silver Sea Remnants",
}
blocked_zone_patterns = {'^Dynamis', 'Meeble'}

function zone_label()
    local info = windower.ffxi.get_info()
    local z = res.zones[info.zone]
    return info.zone, (z and z.en or tostring(info.zone)), info
end

function zone_restricted()
    local id, name, info = zone_label()
    if info.mog_house then return 'Mog House' end
    if settings.learned_zones['z'..id] then return name..' (flagged with //tru block)' end
    if blocked_zone_names:contains(name) then return name end
    for _, pat in ipairs(blocked_zone_patterns) do
        if name:find(pat) then return name end
    end
end

-- Returns a reason string if a summon can not work right now, otherwise nil.
function summon_blocked()
    if settings.zone_check then
        local z = zone_restricted()
        if z then return 'trusts are not allowed in '..z end
    end
    local me = windower.ffxi.get_player()
    if not me then return 'not logged in' end
    if me.status == 1 or me.in_combat then
        return 'you are in combat/engaged (trusts can only be called before gaining enmity)'
    end
    local party = windower.ffxi.get_party()
    if party then
        if (party.party2_count or 0) > 0 or (party.party3_count or 0) > 0 then
            return 'you are in an alliance'
        end
        if party.party1_count > 1 and party.party1_leader and party.party1_leader ~= me.id then
            for i = 1, 5 do
                local m = party['p'..i]
                if m and m.mob and m.mob.spawn_type ~= 14 then
                    return 'you are not the party leader'
                end
            end
        end
    end
end

function learn_zone(on)
    local id, name = zone_label()
    settings.learned_zones['z'..id] = on or nil
    settings:save('all')
    log(name..(on and ' flagged as a restricted zone.' or ' no longer flagged.'))
end

function show_zone()
    local id, name = zone_label()
    local why = summon_blocked()
    log('Zone: '..name..' ('..id..') - '..(why and ('NO: '..why) or 'trusts should be allowed'))
end

-- 3) NPC shop guard: mark trust ciphers you already know and stop you buying them again.
-- Ciphers whose short name differs from the trust's name.
cipher_alias = {
    ['Mihli']='Mihli Aliapoh', ['Naja']='Naja Salaheem', ['Lehko']='Lehko Habhoka',
    ['Domina']='D. Shantotto', ['Lhu']='Lhu Mhakaracca', ['F. Coffin']='Ferreous Coffin',
    ['S. Sibyl']='Star Sibyl', ['Uka']='Uka Totlihn', ['Kuyin']='Kuyin Hathdenna',
    ['Karaha']='Karaha-Baruha', ['Kukki']='Kukki-Chebukki', ['Lhe']='Lhe Lhangavo',
    ['Semih']='Semih Lafihna', ['Kayeel']='Kayeel-Payeel', ['Makki']='Makki-Chebukki',
    ['King']='King of Hearts', ['Ark HM']='AAHM', ['Ark TT']='AATT', ['Ark MR']='AAMR',
    ['Ark EV']='AAEV', ['Ark GK']='AAGK',
}
cipher_map = nil -- item id -> trust entry
cipher_for = {}  -- trust spell id -> cipher name
cipher_enl = {}  -- 'cipher of zeid's alter ego' -> item id (for NPC confirmation lines)
shop_items = {}  -- shop slot -> item id (current NPC shop)

function build_cipher_map()
    if cipher_map then return end
    cipher_map = {}
    local by_name = {}
    for _, t in ipairs(trusts) do by_name[t.english:lower()] = t end
    for id = 10100, 10400 do -- Cipher items live in this id range
        local item = res.items[id]
        local short = item and item.en:match('^Cipher: (.+)$')
        if short then
            local t = by_name[short:lower()] or by_name[(cipher_alias[short] or ''):lower()]
            if t then
                cipher_map[id] = t
                cipher_for[t.id] = item.en
                if item.enl then cipher_enl[item.enl:lower()] = id end
            end
        end
    end
end

cipher_bags = {'inventory','safe','safe2','storage','locker','satchel','sack','case',
    'wardrobe','wardrobe2','wardrobe3','wardrobe4','wardrobe5','wardrobe6','wardrobe7','wardrobe8'}

function cipher_in_bags(item_id)
    for _, bag in ipairs(cipher_bags) do
        local items = windower.ffxi.get_items(bag)
        if items then
            for i = 1, (items.max or 80) do
                local it = items[i]
                if it and it.id == item_id then return bag end
            end
        end
    end
end

-- Returns nil (not a trust cipher), or status 'learned' | 'in bag' | 'new', plus the trust entry.
function cipher_status(item_id)
    build_cipher_map()
    local t = cipher_map[item_id]
    if not t then return nil end
    if windower.ffxi.get_spells()[t.id] then return 'learned', t end
    if cipher_in_bags(item_id) then return 'in bag', t end
    return 'new', t
end

-- On-screen box (replaces the long chat list). Click it, or //tru hide, to dismiss.
box_rows = {}       -- ordered rows currently shown
box_seen = {}       -- item id -> true, so reopening a list does not duplicate rows
box_title = ''
box_token = 0
box = nil

function box_make()
    if not box then
        box = texts.new('${t}', settings.box)
        box:hide()
    end
    return box
end

function box_render()
    local b = box_make()
    local n_new, n_old = 0, 0
    local new_lines, old_lines = {}, {}
    for _, row in ipairs(box_rows) do
        local status, t = cipher_status(row.item)
        local name = res.items[row.item].en
        local label = (t and t.english ~= name:gsub('^Cipher: ', '')) and (name..' ('..t.english..')') or name
        if status == 'new' then
            n_new = n_new + 1
            table.insert(new_lines, '\\cs(120,255,120)NEW   \\cr'..label)
        else
            n_old = n_old + 1
            table.insert(old_lines, (status == 'learned' and '\\cs(255,110,110)OWNED \\cr' or '\\cs(255,200,90)IN BAG\\cr')..' '..label)
        end
    end
    local out = {'\\cs(255,255,160)'..box_title..'\\cr   '..n_new..' new / '..n_old..' owned', ''}
    for _, l in ipairs(new_lines) do table.insert(out, l) end
    if #old_lines > 0 then
        if #new_lines > 0 then table.insert(out, '') end
        for _, l in ipairs(old_lines) do table.insert(out, l) end
    end
    table.insert(out, '')
    table.insert(out, '\\cs(160,160,160)click here or //tru hide to close\\cr')
    b.t = table.concat(out, '\n')
    b:show()
    if (settings.box_seconds or 0) > 0 then
        box_token = box_token + 1
        local token = box_token
        coroutine.schedule(function() if token == box_token then box_hide() end end, settings.box_seconds)
    end
end

function box_add(item_ids, title)
    box_title = title
    for _, id in ipairs(item_ids) do
        if not box_seen[id] then
            box_seen[id] = true
            table.insert(box_rows, {item=id})
        end
    end
    box_render()
end

function box_hide()
    box_token = box_token + 1
    alert_hide()
    if box then box:hide() end
    box_rows, box_seen = {}, {}
end

function box_command(x, y)
    x, y = tonumber(x), tonumber(y)
    if x and y then
        settings.box.pos.x, settings.box.pos.y = x, y
        settings:save('all')
        box_make():pos(x, y)
        log('Box moved to '..x..', '..y)
    else
        log('//tru box <x> <y> moves the box (now '..settings.box.pos.x..', '..settings.box.pos.y..'). //tru hide closes it.')
    end
end

-- Left click on the visible box closes it (and swallows the click so nothing under it is hit).
box_swallow_up = false
windower.register_event('mouse', function(mtype, x, y, delta, blocked)
    if blocked then return end
    if mtype == 1 and alertbox and alertbox:visible() and alertbox:hover(x, y) then
        box_swallow_up = true
        alert_hide()
        return true
    end
    if not box or not box:visible() then return end
    if mtype == 1 and box:hover(x, y) then
        box_swallow_up = true
        box_hide()
        return true
    elseif mtype == 2 and box_swallow_up then
        box_swallow_up = false
        return true
    end
end)

windower.register_event('zone change', function() box_hide() end)

function show_shop()
    local ids = {}
    local slots = {}
    for slot in pairs(shop_items) do table.insert(slots, slot) end
    table.sort(slots)
    for _, slot in ipairs(slots) do
        if cipher_status(shop_items[slot]) then table.insert(ids, shop_items[slot]) end
    end
    if #ids == 0 then
        log('No trust ciphers in the last shop list.')
    else
        box_add(ids, 'Shop - trust ciphers')
    end
end

windower.register_event('incoming chunk', function(id, original)
    if id == 0x03C then
        if original:byte(5) + original:byte(6) * 256 == 0 then shop_items = {} end -- new shop list
        local count = math.floor((#original - 8) / 12)
        for i = 0, count - 1 do
            local p = 9 + i * 12 -- 1-based start of this shop_item entry
            local item_id = original:byte(p + 4) + original:byte(p + 5) * 256
            local slot = original:byte(p + 6) + original:byte(p + 7) * 256 -- entry: price(4) item(2) slot(2) skill(2) rank(2)
            if item_id ~= 0 then shop_items[slot] = item_id end
        end
        if settings.guard ~= 'off' then
            coroutine.schedule(show_shop, 0.5)
        end
    end
end)

windower.register_event('outgoing chunk', function(id, original)
    if id == 0x083 and settings.guard ~= 'off' then
        local slot = original:byte(11)
        local item_id = shop_items[slot]
        local status, t = item_id and cipher_status(item_id)
        if status == 'learned' or status == 'in bag' then
            local msg = res.items[item_id].en..(status == 'learned' and ' - you already know this trust.' or ' - you already have this cipher.')
            if settings.guard == 'block' then
                windower.add_to_chat(207, string.color('Purchase blocked: ', 167)..msg..' (//tru guard warn|off to change)')
                return true
            else
                windower.add_to_chat(207, string.color('Warning: ', 167)..msg)
            end
        end
    end
end)

function set_guard(mode)
    if mode == 'block' or mode == 'warn' or mode == 'off' then
        settings.guard = mode
        settings:save('all')
        log('Shop guard: '..mode)
    else
        log('Shop guard is "'..settings.guard..'". Use //tru guard block | warn | off')
    end
end


-- Capture tool: //tru sniff start, talk to the NPC and open the list, //tru sniff stop.
-- Writes every non-noise packet (hex) and chat line to addons/Trusts/data/sniff_<time>.txt.
sniff_noise = S{0x00D,0x00E,0x037,0x0DF,0x063,0x017,0x028,0x076,0x0E0,0x01B,0x01C,0x01D,0x0F6,0x0F7,0x08D,0x015,0x016,0x0B5,0x0B6,0x061,0x05E}
sniff_file, sniff_count = nil, 0

function hexdump(data)
    return (data:gsub('.', function(c) return string.format('%02X ', c:byte()) end))
end

function sniff_write(line)
    if sniff_file and sniff_count < 600 then
        sniff_count = sniff_count + 1
        sniff_file:write(line, '\n')
        sniff_file:flush()
    end
end

function sniff(mode)
    if mode == 'start' then
        windower.create_dir(windower.addon_path..'data')
        local path = windower.addon_path..'data/sniff_'..os.date('%Y%m%d_%H%M%S')..'.txt'
        sniff_file = io.open(path, 'w')
        sniff_count = 0
        log('Sniffing to '..path..' - talk to the NPC, open the list, then //tru sniff stop')
    elseif mode == 'stop' then
        if sniff_file then sniff_file:close(); sniff_file = nil end
        log('Sniff stopped.')
    else
        log('//tru sniff start | stop')
    end
end

windower.register_event('incoming chunk', function(id, original)
    if sniff_file and not sniff_noise:contains(id) then
        sniff_write(string.format('IN  0x%03X len=%d  %s', id, #original, hexdump(original)))
    end
end)

windower.register_event('outgoing chunk', function(id, original)
    if sniff_file and not sniff_noise:contains(id) then
        sniff_write(string.format('OUT 0x%03X len=%d  %s', id, #original, hexdump(original)))
    end
end)

windower.register_event('incoming text', function(original, modified, mode)
    if sniff_file then sniff_write(string.format('TXT mode=%d  %s', mode, original)) end
end)


-- Greeter Moogle (login campaign) cipher list. Capture showed the NPC sends the offered cipher
-- item ids as 16-bit values at the start of incoming 0x05C event-update packets (16 per page,
-- 0-terminated). We recognise a cipher page when every leading non-zero value is a trust cipher.
function show_cipher_page(items)
    box_add(items, 'Greeter Moogle - trust ciphers')
end

windower.register_event('incoming chunk', function(id, original)
    if id ~= 0x05C or settings.guard == 'off' then return end
    build_cipher_map()
    -- Leading non-zero 16-bit values are offered item ids (a page can mix ciphers and other
    -- prizes). Stop at the first 0 or at a value that is not an item id; keep only trust ciphers.
    local items, others = {}, 0
    for i = 0, 15 do
        local b = 5 + i * 2
        local v = (original:byte(b) or 0) + (original:byte(b + 1) or 0) * 256
        if v == 0 then break end
        if not res.items[v] then items, others = {}, 0 break end
        if cipher_map[v] then table.insert(items, v) else others = others + 1 end
    end
    if #items > 0 then
        coroutine.schedule(function() show_cipher_page(items) end, 0.3)
    end
end)


-- Confirmation warning. Menus built inside the client (Festive Moogle, etc.) send no item list,
-- but the NPC's confirmation line names the cipher ("...1 cipher of Zeid's alter ego, kupo?").
-- Catch that line and warn immediately if you already know the trust / hold the cipher.
alertbox, alert_token, last_confirm = nil, 0, {name=nil, time=0}

function alert_hide()
    alert_token = alert_token + 1
    if alertbox then alertbox:hide() end
end

function alert_show(lines)
    if not alertbox then
        alertbox = texts.new('${t}', settings.alert)
    end
    alertbox.t = table.concat(lines, '\n')
    alertbox:show()
    if (settings.alert_seconds or 0) > 0 then
        alert_token = alert_token + 1
        local token = alert_token
        coroutine.schedule(function() if token == alert_token then alert_hide() end end, settings.alert_seconds)
    end
end

windower.register_event('incoming text', function(original, modified, mode)
    if settings.guard == 'off' then return end
    local low = original:lower()
    if not low:find('cipher of', 1, true) or not low:find('alter ego', 1, true) then return end
    build_cipher_map()
    -- Variants share a prefix ("...Zeid's alter ego" is inside "...Zeid's alter ego II"),
    -- so test the longest cipher descriptions first.
    local ordered = {}
    for enl in pairs(cipher_enl) do table.insert(ordered, enl) end
    table.sort(ordered, function(x, y) return #x > #y end)
    for _, enl in ipairs(ordered) do
        local item_id = cipher_enl[enl]
        if low:find(enl, 1, true) then
            -- the game prints each line 2-3 times; handle it once
            if last_confirm.id == item_id and os.clock() - last_confirm.time < 3 then return end
            last_confirm = {id=item_id, time=os.clock()}
            local status, t = cipher_status(item_id)
            local name = res.items[item_id].en
            if name ~= 'Cipher: '..t.english then name = name..' ('..t.english..')' end
            if status == 'learned' or status == 'in bag' then
                alert_show({
                    '\\cs(255,110,110)ALREADY HAVE: \\cr'..name,
                    status == 'learned' and 'You already know this trust - do not buy it.' or 'This cipher is already in your bags.',
                    '\\cs(160,160,160)click here to close\\cr'})
            else
                alert_show({'\\cs(120,255,120)NEW: \\cr'..name..' - you do not have this trust.'})
            end
            return
        end
    end
end)
