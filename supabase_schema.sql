-- ============================================================
-- 料號編碼系統 v2 — Supabase 資料表建置腳本（整合版，含 BOM 關聯表）
-- 請到 Supabase 專案 → SQL Editor，貼上整段執行一次即可建好全部資料表
-- 內容依「編碼原則規範書 Rev.1.3（20260907）」+ 後續系統內調整
-- ============================================================

-- 1. 料號主表
create table if not exists coding_items (
    code text primary key,
    category text not null,                 -- A/B/C/D/E/F/G/X/Z/M/K/S
    category_label text,
    segments jsonb not null default '{}',    -- 拆解後的各段代碼，方便日後查詢/重組
    description text,
    parent_code text references coding_items(code) on delete set null,  -- 已不使用，改用 bom_links，保留欄位相容
    quantity numeric,   -- 已不使用，改用 bom_links.quantity，保留欄位相容
    unit text,          -- 已不使用，改用 bom_links.unit，保留欄位相容
    status text not null default '啟用',      -- 啟用/草稿/停用/淘汰
    locked boolean not null default false,
    lock_reason text,
    is_deleted boolean not null default false,
    deleted_at timestamptz,
    created_at timestamptz not null default now()
);

create index if not exists idx_coding_items_category on coding_items(category);
create index if not exists idx_coding_items_deleted on coding_items(is_deleted);

-- 2. 代碼對照表（產品分類、產品線、材質類別、客戶碼…全部共用一張表，用 list_name 區分）
create table if not exists lookup_items (
    id bigint generated always as identity primary key,
    list_name text not null,     -- 例如 product_class_a / product_class_b / product_line /
                                  -- raw_material_class / material_class_num / customer_code / tool_customer_code
    code text not null,
    label text not null,
    note text,
    sort_order int not null default 0,
    created_at timestamptz not null default now(),
    unique (list_name, code)
);

-- 3. 操作日誌
create table if not exists operation_logs (
    id bigint generated always as identity primary key,
    action text,
    code text,
    detail jsonb,
    created_at timestamptz not null default now()
);

-- 4. BOM 歸屬關聯表（多對多：同一料號可同時歸屬多個成品／半成品的 BOM）
create table if not exists bom_links (
    id bigint generated always as identity primary key,
    parent_code text not null references coding_items(code) on update cascade on delete cascade,
    child_code text not null references coding_items(code) on update cascade on delete cascade,
    quantity numeric,
    unit text,
    created_at timestamptz not null default now(),
    unique (parent_code, child_code)
);

create index if not exists idx_bom_links_parent on bom_links(parent_code);
create index if not exists idx_bom_links_child on bom_links(child_code);

-- ============================================================
-- RLS：開放 anon 金鑰可直接讀寫（前端用 publishable key 操作）
-- ============================================================
alter table coding_items enable row level security;
alter table lookup_items enable row level security;
alter table operation_logs enable row level security;
alter table bom_links enable row level security;

drop policy if exists "coding_items_all" on coding_items;
create policy "coding_items_all" on coding_items for all using (true) with check (true);

drop policy if exists "lookup_items_all" on lookup_items;
create policy "lookup_items_all" on lookup_items for all using (true) with check (true);

drop policy if exists "operation_logs_all" on operation_logs;
create policy "operation_logs_all" on operation_logs for all using (true) with check (true);

drop policy if exists "bom_links_all" on bom_links;
create policy "bom_links_all" on bom_links for all using (true) with check (true);

-- ============================================================
-- 5. 預帶入代碼對照表（依編碼原則規範書 Rev.1.3 / 20260907，含後續系統內異動）
-- ============================================================
insert into lookup_items (list_name, code, label, note, sort_order) values
-- 產品分類（A 成品新品／C 半成品／X 虛擬階 共用，第2碼）
('product_class_a', 'P', '精密組件', '乘載物尺寸類，如 9" 光罩盒', 1),
('product_class_a', 'C', '化學流體控制與傳載', '化學桶、PFA閥件/管材', 2),
('product_class_a', 'E', '設備', '機型型號類，如 AOI 檢測設備', 3),
-- 產品分類（B 成品維修品 第2碼）
('product_class_b', 'W', '清洗封裝', '僅用於客供清洗件', 1),
-- 產品線代碼（A/B/C/X 共用，第3~5碼／成品名稱；依英文字母排序）
('product_line', 'AOI', 'Automatic Optical Inspection', '自動光學檢測設備', 1),
('product_line', 'ASM', '機構組裝類', '機構組裝子系統', 2),
('product_line', 'ATM', 'Auto Transfer Machine', '自動搬運機', 3),
('product_line', 'CAB', '線材/線纜類', '線材線纜子系統', 4),
('product_line', 'CHE', '化學耗材類', '化學耗材子系統', 5),
('product_line', 'ELE', '電子電控類', '電子電控子系統', 6),
('product_line', 'EUV', 'Extreme UltraViolet', 'EUV光罩盒，六吋EUV光罩盒=06A01', 7),
('product_line', 'FAS', '標準鎖附五金類', '標準五金子系統', 8),
('product_line', 'FOS', 'Front Opening Shipping box', '晶圓傳送盒(FOSB)，晶圓尺寸8吋=0008/12吋=0012', 9),
('product_line', 'FOU', 'Front Opening Unified pod', '晶圓載具(FOUP)，晶圓尺寸8吋=0008/12吋=0012', 10),
('product_line', 'FRC', 'Frame Cassette', '晶圓框架載具，晶圓尺寸8吋=0008/12吋=0012', 11),
('product_line', 'MAS', 'MASk box', '光罩盒/大尺寸光罩盒，依型號定義規格碼', 12),
('product_line', 'MEC', '金屬材料/加工件類', '金屬加工件，規格碼5碼：1st=1板金/2CNC，2nd=0陽極/1無陽極，3rd=0熱處理/1無熱處理，4th=0噴砂/1無噴砂，5th=0拉絲/1無拉絲', 13),
('product_line', 'MWS', 'Micro Warehouse System', '微型倉儲', 14),
('product_line', 'OHB', 'OHB-N2配電盤', '', 15),
('product_line', 'OPT', '光學元件類', '光學元件子系統', 16),
('product_line', 'PAC', '包裝/紙材類', '包裝材料子系統', 17),
('product_line', 'PDB', 'Power Distribution Board', '配電盤', 18),
('product_line', 'PFP', 'PFA Pipe', 'PFA管材，依外徑換算(mm/25=inch)', 19),
('product_line', 'PFV', 'PFA Valve', 'PFA閥件，規格碼=0304', 20),
('product_line', 'PLA', '塑膠類', '塑膠材料子系統', 21),
('product_line', 'PNE', '氣動氣路類', '氣動氣路子系統', 22),
('product_line', 'RSP', 'Reticle SMIF Pod', '自動化光罩載具，六吋=06A01/八吋=08A01', 23),
('product_line', 'RUB', '橡膠/矽膠類', '橡膠矽膠子系統', 24),
('product_line', 'SCD', 'Specialty Chemical Drum', '特用化學桶，裝填容量(L)如200L=0200', 25),
('product_line', 'TRA', '傳動元件類', '傳動元件子系統', 26),
-- 原料類別碼（D 原料 第2~4碼，材質未達3碼以Z補足）
('raw_material_class', 'PFA', 'PFA', '全氟烷氧基聚合物', 1),
('raw_material_class', 'PPS', 'PPS', '聚苯硫醚', 2),
('raw_material_class', 'POM', 'POM', '聚甲醛（賽鋼）', 3),
('raw_material_class', 'ABS', 'ABS', '丙烯腈丁二烯苯乙烯', 4),
('raw_material_class', 'PPC', 'PPC', '聚碳酸酯（PC變形）', 5),
('raw_material_class', 'PPE', 'PPE', '聚丙烯（PP延伸）', 6),
('raw_material_class', 'UPE', 'UHMW-PE', '超高分子量聚乙烯', 7),
('raw_material_class', 'PEK', 'PEEK', '聚醚醚酮', 8),
('raw_material_class', 'PCZ', 'PC（補Z）', '聚碳酸酯（未達3碼，以Z補足）', 9),
('raw_material_class', 'PPZ', 'PP（補Z）', '聚丙烯（未達3碼，以Z補足）', 10),
('raw_material_class', 'PMA', 'PMMA', '', 11),
('raw_material_class', 'PBT', 'PBT', '', 12),
('raw_material_class', 'PEF', 'PEEK+CF', '', 13),
('raw_material_class', 'PCA', 'PC+CF+APWA', '', 14),
('raw_material_class', 'HDP', 'HDPE', '', 15),
('raw_material_class', 'PCC', 'PC+CF+CB', '', 16),
('raw_material_class', 'PCN', 'PC+CNT+CN', '', 17),
-- 類別碼（E 物料／F 客供料／Z 耗材費用 共用，2碼數字；英文字母僅為助記，非實際編碼內容）
('material_class_num', '01', '塑膠類', 'PLAstic - 客供塑膠原料或零件', 1),
('material_class_num', '02', '金屬件', 'MeTaL - 螺絲、螺帽、彈簧、軸承', 2),
('material_class_num', '03', '電控類', 'ELEctrical - 馬達、感測器、繼電器、PLC', 3),
('material_class_num', '04', '端子類', 'TeRMinal - 端子、線材', 4),
('material_class_num', '05', '化學品', 'CHeMical - 清洗劑、溶劑…等化學品', 5),
('material_class_num', '06', '包材', 'PacKaGing - 紙箱、棧板、PE袋', 6),
('material_class_num', '07', '接頭類', 'Y-ConnecTor - Y接頭、快插接頭（含尺寸unit:mm）', 7),
('material_class_num', '08', '橡膠/墊片', 'RuBbeR - O-Ring、緩衝墊、橡膠矽膠', 8),
('material_class_num', '09', '外購塑膠件', 'PLastic Part - 非自製之外購塑膠零件', 9),
('material_class_num', '99', '其他', 'OTHers - 未分類雜項', 10),
-- 客戶碼（F 客供料，固定6碼；聖凰/宜特/圓達尚未取得正式代碼，待業務提供後再補）
('customer_code', 'A00001', '家登', '', 1),
('customer_code', 'A00002', '碩頂', '', 2),
-- 客戶別代碼（M 模具／K 治具／S 檢具 共用，第2~3碼；依規範書第十二章對照表，後續新增客戶依序編號）
('tool_customer_code', '01', '圓達', '', 1),
('tool_customer_code', '02', '家登', '', 2),
('tool_customer_code', '03', '碩頂', '', 3)
on conflict (list_name, code) do nothing;
