# Исправление Windows-сборки: ATL

Ошибка возникала на шаге, который пытался изменить уже установленный Visual Studio на GitHub-hosted runner:

```text
ATL installation failed with code 1
```

GitHub-образ `windows-2022` уже содержит Visual Studio 2022 и компонент Visual C++ ATL.

Workflow теперь:

1. использует `windows-2022`;
2. не запускает `vs_installer.exe`;
3. только проверяет наличие ATL;
4. проверяет наличие `atlbase.h`;
5. продолжает обычную Flutter Windows-сборку.

Изменён файл:

```text
.github/workflows/build_windows.yml
```
