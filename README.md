環境樹 - 主機與容器一體
=======

> 養護工： 張本微 Bway.Cer

在 GitHub 上栽種我的文字樹，建造專屬我的莊園。

`ysenv` 依照 `envfile/config.yaml` 設定對主機建立鏈結； 對容器建立掛載。


## 使用

**架構：**

  ```txt
  ├── [private_envfile/ ...]
  └── path/to/any
      └── envfile/
          └── pub/
              ├── ysenv/
              │   └── .local/
              │       ├── bin/
              │       │   └── ysenv
              │       └── share/bash-completion/completions/
              │           └── ysenv.bash
              ├── share/
              │   └── .bashrc
              ├── ...
              └── config.yaml
  ```

> 📝 `envfile/config.yaml` 的位置可使用 `YSENV_CONFIG_PATH` 環境變數來指定。

> 📝 在 `./config.yaml.example` 中 `envfile` 目錄被放於 `~/ys/envfile` 路徑只是筆者習關，實際不依賴特定路徑。

**建立環境：**

  ```bash
  [[ -d ~/.local/bin ]] || mkdir -p ~/.local/bin
  cp ./config.yaml.example ./config.yaml
  ./init.sh
  ```
