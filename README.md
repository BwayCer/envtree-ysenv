環境樹 - 主機與容器一體
=======

> 養護工： 張本微 Bway.Cer

在 GitHub 上栽種我的文字樹，建造專屬我的莊園。


## 目的

```txt
├── [private/ ...]
└─ … ── envfile/
        ├── ysenv/
        │   └── .local/
        │       ├── bin/
        │       │   └── ysenv
        │       └── share/bash-completion/completions/
        │           └── ysenv.bash
        ├── ...
        └── config.yaml
```

`ysenv` 依照 `config.yaml` 設定對主機建立鏈結； 對容器建立掛載。
