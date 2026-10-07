@echo off
REM publish_to_github.bat - push to GitHub -> auto build+deploy -> get URL
REM 1) Create an empty repo on github.com (green New button). Note its name.
REM 2) Make a fine-grained PAT with 'contents: write' at github.com/settings/tokens
set /p GHUSER=GitHub username: 
set /p GHREPO=GitHub repo name: 
set /p GHTOKEN=GitHub PAT (contents:write): 
git init
git config user.name "%GHUSER%"
git config user.email "%GHUSER%@users.noreply.github.com"
git branch -M main
git remote remove origin 2>nul
git remote add origin https://%GHUSER%:%GHTOKEN%@github.com/%GHUSER%/%GHREPO%.git
git add -A
git commit -m "deploy"
git push -u origin main
echo.
echo Your link will be: https://%GHUSER%.github.io/%GHREPO%/
echo Go to repo Settings > Pages > Source = GitHub Actions, then wait ~2 min.
pause
