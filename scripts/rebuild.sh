# install
bundle install

# clean
bundle exec jekyll clean

# build
JEKYLL_ENV="production" bundle exec jekyll build

# deploy
rm -rf /var/www/html/*
cp -a ./_site/* /var/www/html