-- ============================================================
-- 遷移腳本：BOM 歸屬改為多對多（同一物料可同時歸屬多個成品）
-- 請到 Supabase 專案 → SQL Editor，貼上整段執行一次
-- ============================================================

-- 1. 新增 BOM 關聯表：一筆代表「某料號被用在某上階料號的 BOM 裡，用量多少」
create table if not exists bom_links (
    id bigint generated always as identity primary key,
    parent_code text not null references coding_items(code) on delete cascade,
    child_code text not null references coding_items(code) on delete cascade,
    quantity numeric,
    unit text,
    created_at timestamptz not null default now(),
    unique (parent_code, child_code)
);

create index if not exists idx_bom_links_parent on bom_links(parent_code);
create index if not exists idx_bom_links_child on bom_links(child_code);

alter table bom_links enable row level security;
drop policy if exists "bom_links_all" on bom_links;
create policy "bom_links_all" on bom_links for all using (true) with check (true);

-- 2. 把既有 coding_items.parent_code 的歸屬資料搬進 bom_links
insert into bom_links (parent_code, child_code, quantity, unit)
select parent_code, code, quantity, unit
from coding_items
where parent_code is not null
on conflict (parent_code, child_code) do nothing;

-- 3. 舊的 parent_code / quantity / unit 欄位不再使用，清空避免混淆（保留欄位本身，未來如需可再利用）
update coding_items set parent_code = null, quantity = null, unit = null where parent_code is not null;
