# Lofi custom planner

[![CI](https://github.com/DimasterZT/Lofi-custom-planner/actions/workflows/ci.yml/badge.svg)](https://github.com/DimasterZT/Lofi-custom-planner/actions/workflows/ci.yml)

Невеликий локальний планер для Windows: справи перед очима, власні нотатки та оформлення під себе. Перший публічний прототип на PowerShell/WPF.

## Можливості

- Світла/темна тема, основний колір і колір полотна.
- Напівпрозора рамка, прямі або заокруглені кути.
- Галочки виконання та збереження стану.
- Кнопка **+** для багаторядкової нотатки.
- Перетягування за назву дня; позиція вікна запам'ятовується.
- Розтягування за краї, масштабування й прокрутка.
- Режим «Поверх інших вікон».

## Запуск

Потрібна Windows 10/11 із Windows PowerShell 5.1 та .NET Framework/WPF. Додаткові бібліотеки не встановлюються.

1. Завантаж ZIP із [Releases](https://github.com/DimasterZT/Lofi-custom-planner/releases).
2. Повністю розпакуй у власну папку, доступну для запису.
3. Відкрий PowerShell у цій папці та виконай:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Run.ps1
```

Так само можна запустити клонований репозиторій. Нові нотатки, галочки й оформлення зберігаються локально біля `src/Plan.ps1`. Ці JSON-файли ігноруються Git та не потрапляють у ZIP.

**Поточне обмеження:** шість задач — демонстраційні. Можна створювати власні текстові нотатки; повного редактора задач і дат ще немає. Ця копія не імпортує особисті справи автора й не встановлює автозапуск самостійно.

## Розробка

```powershell
git clone https://github.com/DimasterZT/Lofi-custom-planner.git
cd Lofi-custom-planner
git switch -c feat/my-change
# Внеси зміни.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Check.ps1
git add src/Plan.ps1
git commit -m "feat: describe the change"
git push -u origin feat/my-change
```

Створи pull request до `main` у GitHub або Orca. CI перевіряє PowerShell-синтаксис, сценарії WPF в окремій тимчасовій папці та складання ZIP. Після зелених перевірок використовується squash merge. Повний ручний сценарій роботи мишею CI не замінює.

```text
feature branch → commit → push → PR → Windows CI → squash merge → main
                                                               ↓
                                                           tag vX.Y.Z
                                                               ↓
                                                      ZIP + SHA256 release
```

## Реліз для власника репозиторію

Після merge онови локальну стабільну гілку та створи новий тег версії:

```powershell
git switch main
git pull --ff-only
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin v0.2.0
```

Workflow `Release` повторно перевірить програму, збере ZIP і SHA256 та опублікує GitHub Release. Уже опубліковані теги не перезаписуються; для виправлення створюй нову версію.

## Структура

```text
src/Plan.ps1              WPF-вікно й локальне збереження
Run.ps1                   запуск без окремого вікна консолі
scripts/Check.ps1          ізольована перевірка
scripts/Package.ps1        ZIP із дозволеного списку файлів
.github/workflows/        PR-перевірки та релізи
```

Публічна ліцензія ще не обрана автором.
