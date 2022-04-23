set -e

bash scripts/build.sh

if test -e "./_site/index.html";then
  echo "It builds!"
  rm -Rf _site
else
  echo "Huh. That's odd. The blog site doesn't seem to build."
  exit 1
fi

gem build moving.gemspec