-- ============================================================
-- 遷移腳本：允許修改料號編碼本身，並讓 bom_links 的歸屬關聯自動跟著更新
-- 請到 Supabase SQL Editor 貼上執行一次
-- ============================================================

alter table bom_links drop constraint if exists bom_links_parent_code_fkey;
alter table bom_links add constraint bom_links_parent_code_fkey
    foreign key (parent_code) references coding_items(code)
    on update cascade on delete cascade;

alter table bom_links drop constraint if exists bom_links_child_code_fkey;
alter table bom_links add constraint bom_links_child_code_fkey
    foreign key (child_code) references coding_items(code)
    on update cascade on delete cascade;
