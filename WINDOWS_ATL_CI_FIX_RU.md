# Исправление Windows-сборки: ATL

Ошибка возникала на шаге, который пытался изменить уже установленный Visual Studio на GitHub-hosted runner:

```text
ATL installation failed with code 1
```

GitHub-образ `windows-2022` уже содержит:

- Visual Studio Enterprise 2022;
- `Microsoft.VisualStudio.Component.VC.Tools.x86.x64`;
- `Microsoft.VisualStudio.Component.VC.ATL`;
- заголовок `atlbase.h`.

Поэтому workflow теперь:

1. использует фиксированный образ `windows-2022`;
2. не запускает Visual Studio Installer;
3. только проверяет наличие ATL и `atlbase.h`;
4. продолжает обычную Flutter Windows-сборку.

Изменённый файл:

```text
.github/workflows/build_windows.yml
```
