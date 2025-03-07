# No More Room in Hell Play To Earn
Base template for running a server with play to earn support

## Functionality
- Surviving rounds will earn PTE
- The more rounds the player survive the more PTE he will earn
- Setup wallet as command ``!wallet 0x123...``

## Configuring
To configure you will need to manually change some values inside the file before compiling

``Database Version``
```cpp
bool        alertNonWalletRegisteredPlayers = true;
bool        alertPlayerIncomings            = true;

char        waveRewards[15][20]             = { "100000000000000000", "10000000000000000", "100000000000000000",
                             "100000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "300000000000000000" };
int         maxWaves                        = 15;
char        waveRewardsShow[15][20]         = { "0.1", "0.1", "0.1",
                                 "0.1", "0.2", "0.2",
                                 "0.2", "0.2", "0.2",
                                 "0.2", "0.2", "0.2",
                                 "0.2", "0.2", "0.3" };

bool        checkBot                        = true;
int         checkBotDelay                   = 60;
int         checkBotMaxIdle                 = 240;
```

## Using Database
- Download [No More Room in Hell](https://nomoreroominhell.fandom.com/wiki/Dedicated_Server_Setup) server files
- Install [sourcemod](https://www.sourcemod.net/downloads.php) and [metamod](https://www.sourcemm.net/downloads.php/?branch=stable)
- Install [sm_json](https://github.com/clugg/sm-json) for [sourcemod](https://www.sourcemod.net/downloads.php), just place the addons folder inside TeamFortress2/tf
- Install a database like mysql or mariadb
- Create a user for the database: GRANT ALL PRIVILEGES ON pte_wallets.* TO 'pte_admin'@'localhost' IDENTIFIED BY 'supersecretpassword' WITH GRANT OPTION; FLUSH PRIVILEGES;
- Create a table named ``nmrih``:
```sql
CREATE TABLE nmrih (
    uniqueid VARCHAR(255) NOT NULL PRIMARY KEY,
    walletaddress VARCHAR(255) NOT NULL,
    value DECIMAL(50, 0) NOT NULL DEFAULT 0
);
```
- Copy the play_to_earn_survival_db.sp inside NoMoreRoomInHell/nmrih/addons/sourcemod/scripting
- Inside the NoMoreRoomInHell/nmrih/addons/sourcemod/scripting should be a file to compile, compile it giving the play_to_earn_survival_db.sp as parameter
- The file should be in NoMoreRoomInHell/nmrih/addons/sourcemod/scripting/compiled folder, copy the file compiled and place it in NoMoreRoomInHell/nmrih/addons/sourcemod/plugins folder
- Now you need to configure your database, go to NoMoreRoomInHell/nmrih/addons/sourcemod/databases.cfg, and add the database credentials
- Run the server normally, players should register their wallets using the command ``!wallet 0x123...``

# Recomendations
- [Anti Server Lag Exploits](https://forums.alliedmods.net/showthread.php?p=2788390)