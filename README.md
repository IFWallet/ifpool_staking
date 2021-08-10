# IFPool Staking Protocol
IFPool is an open source Staking Protocol for CSC (CoinEx Smart Chain) node staking. current version 1.0.

## Document
IFPool supports CSC node staking (staking CET to mining CET) and IFT staking (staking IFT to earn CET - the platform profits)

Please visit [https://ifpool.io](https://ifpool.io) to use App.

How to use, please read [guide](https://yuque.com/ifpool).

## Source Code
The source code included is the production version of the protocol. Eventual changes (smart contracts updates, bug fixes, etc.) will be applied through subsequent merge requests.

## Audit Report
Waiting for Audit in a soon future. The Audit Report will upload to here when it's done.

Contract are deployed to CSC(CoinEx Smart Chain):

```
IFPool: 0x633acb5ca22c5851b4278B062AA6B567791F2C5B
IFT Vault: 0x918F0ec3d0cdb94e39fCad6dE40365b5f85c699A
IFT Staker: 0xDfEcB6584366f3111e930fEf5A3E921896C90d65
IFT Token: 0x1D7C98750A47762FA8B45c6E3744aC6704F44698
```

## How it works?
User staking CET to IFPool, then IFPool will create an delegate contract for users, which staking to nodes, and record users position, this will using to calculate user's rewards. Staking CET will get CET from CSC nodes and get IFT from IFPool. Protocol will charge 10% from user's rewards as platform profits.

After claim your IFT, you can stake IFT to get platform profits, according to last month profit of IFPool protocol.





