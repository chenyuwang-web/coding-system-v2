# 在 Synology NAS 上自架 PostgREST（取代 Supabase）

這個資料夾裡有兩個檔案：
- `docker-compose.yml` — 定義兩個容器：PostgreSQL（存資料）+ PostgREST（把資料庫變成 REST API）
- `init.sql` — 資料庫第一次啟動時自動執行，會建好所有資料表跟預設代碼對照表

## 步驟

### 1. 改密碼
打開 `docker-compose.yml` 跟 `init.sql`，把裡面的：
- `CHANGE_ME_DB_PASSWORD` 換成一組密碼（自己保管好，這是資料庫管理密碼）
- `CHANGE_ME_AUTH_PASSWORD` 換成另一組密碼（`docker-compose.yml` 跟 `init.sql` 裡都要改成**一樣的**，這是 PostgREST 連資料庫用的）

### 2. 建立 Container Manager 專案
1. Synology DSM → 打開 **Container Manager**
2. 左側選單 **專案（Project）** → **建立**
3. 專案名稱填 `coding-system` 之類的
4. 路徑選一個資料夾（例如 `/docker/coding-system`），把 `docker-compose.yml` 跟改好密碼的 `init.sql` 上傳到這個資料夾（用 **File Station** 上傳即可）
5. Container Manager 建立專案時選「使用現有的 docker-compose.yml」，指向剛剛上傳的檔案
6. 建立並啟動

第一次啟動時，PostgreSQL 容器會自動執行 `init.sql`（因為 `docker-compose.yml` 裡有掛載這個檔案），把資料表跟代碼對照表都建好，不用再手動貼 SQL。

### 3. 確認容器有跑起來
Container Manager 裡應該會看到 `db` 跟 `postgrest` 兩個容器都是「執行中」的狀態。

### 4. 找到 NAS 的內網位址
DSM 左上角或「控制台 → 網路」可以看到 NAS 的內網 IP（類似 `192.168.1.126`）。PostgREST 開在 port `3000`，所以之後系統要連的網址會是：
```
http://192.168.1.126:3000
```
（把 IP 換成你 NAS 實際的內網 IP）

### 5. 告訴我這個網址
把最終的 `http://你的NAS-IP:3000` 貼給我，我會把 `index.html` 裡的設定改成：
```js
const SUPABASE_URL = 'http://192.168.1.126:3000';  // 換成你的 NAS 網址
const SUPABASE_KEY = '';                             // 自架不需要金鑰，留空
const REST_PATH_PREFIX = '';                         // 自架不需要 /rest/v1 前綴
```
改完部署上線，系統就會改連你 NAS 上的資料庫，只有辦公室內網連得到（跟你原本要求的一樣）。

## 注意事項
- 這個設定是**內網限定**，只有連在同一個公司網路的電腦才能連到 `192.168.1.126:3000`，在家或外地無法使用（符合你當初的需求）
- 因為是內網用，這裡沒有做額外的登入驗證，任何連得到這個 port 的人都能讀寫資料庫，請確保 NAS 的防火牆只允許內網存取，不要對外網開放這個 port
- 之後如果要備份資料，備份 `pgdata` 這個資料夾就等於備份整個資料庫
