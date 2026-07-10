-- ============================================================
-- 料號編碼系統 v2 — Supabase 資料表建置腳本
-- 請到 Supabase 專案 → SQL Editor，貼上整段執行一次即可
-- （沿用現有 product-code-system 專案 URL/Key，但使用全新的資料表，
-- 　不會動到既有的 product_codes 資料表）
-- ============================================================

-- 1. 料號主表
create table if not exists coding_items (
    code text primary key,
    category text not null,                 -- A/B/C/D/E/F/X/Z
    category_label text,
    segments jsonb not null default '{}',    -- 拆解後的各段代碼，方便日後查詢/重組
    description text,
    parent_code text references coding_items(code) on delete set null,
    quantity numeric,
    unit text,
    status text not null default '啟用',      -- 啟用/草稿/停用/淘汰
    locked boolean not null default false,
    lock_reason text,
    is_deleted boolean not null default false,
    deleted_at timestamptz,
    created_at timestamptz not null default now()
);

create index if not exists idx_coding_items_category on coding_items(category);
create index if not exists idx_coding_items_parent on coding_items(parent_code);
create index if not exists idx_coding_items_deleted on coding_items(is_deleted);

-- 2. 代碼對照表（產品分類、產品線、製程碼、材質類別、客戶碼…全部共用一張表，用 list_name 區分）
create table if not exists lookup_items (
    id bigint generated always as identity primary key,
    list_name text not null,     -- 例如 product_class_a / product_class_b / product_line /
                                  -- process_code / raw_material_class / component_class /
                                  -- consumable_class / customer_code
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

-- ============================================================
-- RLS：與現有 product_codes 相同做法，開放 anon 金鑰可直接讀寫
-- （前端用 publishable key 操作，安全性等同現有系統）
-- ============================================================
alter table coding_items enable row level security;
alter table lookup_items enable row level security;
alter table operation_logs enable row level security;

drop policy if exists "coding_items_all" on coding_items;
create policy "coding_items_all" on coding_items for all using (true) with check (true);

drop policy if exists "lookup_items_all" on lookup_items;
create policy "lookup_items_all" on lookup_items for all using (true) with check (true);

drop policy if exists "operation_logs_all" on operation_logs;
create policy "operation_logs_all" on operation_logs for all using (true) with check (true);

-- ============================================================
-- 4. 預帶入參考檔案（產品編碼20260709.xlsx）裡的初始代碼對照表
-- ============================================================
insert into lookup_items (list_name, code, label, note, sort_order) values
-- 產品分類（A 成品新品 第2碼）
('product_class_a', 'P', '精密組件', '乘載物尺寸類，如 9" 光罩盒', 1),
('product_class_a', 'C', '化學品載具', '裝填容量類，如 200L 化學桶', 2),
('product_class_a', 'E', '設備', '機型型號類，如 AOI 檢測設備', 3),
-- 產品分類（B 成品維修品 第2碼）
('product_class_b', 'W', '清洗封裝', '僅用於客供清洗件', 1),
-- 產品線代碼（A/B/C/X 共用，第3~5碼／成品名稱）
('product_line', 'RSP', 'Reticle SMIF Pod', '光罩盒', 1),
('product_line', 'SCD', 'Special Chemical Drum', '特用化學品桶', 2),
('product_line', 'AOI', 'Automatic Optical Inspection', '自動光學檢測設備', 3),
('product_line', 'MAS', '光罩盒', '', 4),
('product_line', 'PDB', '配電盤', '', 5),
('product_line', 'MWS', '微型倉儲', '', 6),
('product_line', 'ATM', '自動搬運機', '', 7),
-- 製程碼（C 半成品 第2碼，全部6種）
('process_code', 'J', '射出件', 'inJection，適用光罩盒/FOUP塑膠件；規格碼＝模穴尺寸或模具代號後4碼', 1),
('process_code', 'A', '組立件', 'Assembly，適用所有產品線；規格碼＝所屬成品尺寸碼', 2),
('process_code', 'M', '機構加工件', 'Machined，適用自動化設備；規格碼＝設備型號後4碼', 3),
('process_code', 'E', '電控組立', 'Electrical，適用自動化設備', 4),
('process_code', 'W', '線束', 'Wiring，適用自動化設備', 5),
('process_code', 'F', '鈑金件', 'Sheet Metal，適用自動化設備', 6),
-- 原料類別碼（D 原料 第2~4碼，材質未達3碼以 Z 補碼）
('raw_material_class', 'PFA', 'PFA', '', 1),
('raw_material_class', 'PPS', 'PPS', '', 2),
('raw_material_class', 'POM', 'POM', '', 3),
('raw_material_class', 'ABS', 'ABS', '', 4),
('raw_material_class', 'PPC', 'PPC', '', 5),
('raw_material_class', 'PPE', 'PPE', '', 6),
('raw_material_class', 'PEK', 'PEEK', '', 7),
('raw_material_class', 'PCZ', 'PC（補Z）', '', 8),
('raw_material_class', 'PPZ', 'PP（補Z）', '', 9),
-- 物料/客供料 類別碼（E 第3~5碼、F 第2~4碼 共用；PLA 僅 F 客供料使用）
('component_class', 'PLA', '塑膠類', '僅適用於 F 客供料', 0),
('component_class', 'MTL', '金屬件', '', 1),
('component_class', 'ELE', '電控類', '', 2),
('component_class', 'TRM', '端子類', '', 3),
('component_class', 'CHM', '化學品', '', 4),
('component_class', 'PKG', '包材', '', 5),
('component_class', 'YCT', '接頭類', '', 6),
('component_class', 'RBR', '橡膠/墊片', '', 7),
('component_class', 'PLP', '外購塑膠件', '', 8),
('component_class', 'OTH', '其他耗材', '', 9),
-- 耗材/費用 類別碼（Z 第2~4碼）
('consumable_class', 'CHM', '化學藥劑類', '', 1),
('consumable_class', 'OIL', '油品/潤滑類', '', 2),
('consumable_class', 'TAP', '膠帶類', '', 3),
('consumable_class', 'PKM', '包裝耗材類', '', 4),
('consumable_class', 'OFC', '文具用品', '', 5),
('consumable_class', 'SFT', '防護用品', '', 6),
('consumable_class', 'CLN', '清潔用品', '', 7),
('consumable_class', 'TOL', '工具類耗材', '', 8),
('consumable_class', 'OTH', '其他雜項', '', 9),
-- 客戶碼（F 客供料 第5~10碼，固定6碼，待業務更新為實際代碼前先以 X 補位占位）
('customer_code', 'JDXXXX', '家登', '待業務更新實際客戶碼（目前為占位碼）', 1),
('customer_code', 'JSXXXX', '晶晟精密', '待業務更新實際客戶碼（目前為占位碼）', 2),
('customer_code', 'NTXXXX', '耐特科技', '待業務更新實際客戶碼（目前為占位碼）', 3),
('customer_code', 'SHXXXX', '聖凰', '待業務更新實際客戶碼（目前為占位碼）', 4)
on conflict (list_name, code) do nothing;
