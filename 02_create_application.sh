#!/bin/bash
set -x

read -p "Create github repository. Press enter to continue"

# create github repository "${SITE}"
curl -u "${GITHUB_USERNAME}":"${GITHUB_TOKEN}" https://api.github.com/user/repos \
-d "{\"name\":\"${SITE}\"}"
# delete repo
#curl -X DELETE -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com/repos/${GITHUB_USERNAME}/${SITE}

read -p "Create our web-application. Press enter to continue"

# remove application
rm -rf ./$SITE || true
# create the static content blog site
hugo new site $SITE
# clone in theme we want to use
git -C $SITE/ clone https://github.com/budparr/gohugo-theme-ananke.git themes/gohugo-theme-ananke
# we don't want repo info
/bin/rm -rf ${SITE}/themes/gohugo-theme-ananke/.git
git -C $SITE/ clone https://github.com/Lednerb/bilberry-hugo-theme.git themes/bilberry-hugo-theme
# we don't want repo info
/bin/rm -rf ${SITE}/themes/bilberry-hugo-theme/.git
echo "# $SITE" >> $SITE/README.md
# create blog content
pushd $SITE
hugo new posts/handy-bash-one-liners.md
hugo new posts/kubectl.md
touch data/.gitkeep
touch layouts/.gitkeep
touch static/.gitkeep
popd
# copy in some content
/bin/cp -rf content/posts/* $SITE/content/posts
# we have all our content, create gir repo
git -C $SITE/ init
git -C $SITE/ add .
git -C $SITE/ commit -m "Create ${SITE} repository"
# upload content to github
git -C ${SITE}/ remote add origin https://github.com/${GITHUB_USERNAME}/${SITE}.git
git -C ${SITE}/ push -u origin master

read -p "Set theme (t1) for web-application. Press enter to continue"

# push theme 'ananke' to github
export K8S_BLOG_TAG="t1"
# enable theme 'ananke'
pushd $SITE
/bin/cp -avR themes/gohugo-theme-ananke/exampleSite/* .
sed -i -e 's|baseURL =.*|baseURL = "/"|g' ./config.toml
sed -i -e 's|themesDir =.*|themesDir = "themes"|g' ./config.toml
popd
# commit change and push to github
git -C ${SITE}/ commit -a -m "Set theme to ${K8S_BLOG_TAG}"
git -C ${SITE}/ push -u origin master

read -p "We are ready to login to dockerhub, create and push image with theme(t1). Press enter to continue"

# login to dockerhub
cat ./private/secret.txt | docker login -u ${DOCKER_HUB_USERNAME} --password-stdin

# generate our Dockerfile
cat > Dockerfile <<EOF
FROM ubuntu
MAINTAINER Bjarte Brandt <bjarte.brandt@tv2.no>
USER root
RUN apt-get update && apt-get install -y \
    wget \
    git \
    nginx
RUN wget --quiet https://github.com/spf13/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_Linux-64bit.tar.gz && \
    tar -xf hugo_${HUGO_VERSION}_Linux-64bit.tar.gz && \
    chmod +x hugo && \
    mv hugo /usr/local/bin/hugo && \
    rm -rf hugo hugo_${HUGO_VERSION}_Linux-64bit.tar.gz
RUN git clone https://github.com/${GITHUB_USERNAME}/${SITE}.git
RUN hugo -D -s ${SITE} -d /var/www/html
CMD ["nginx", "-g", "daemon off;"]
EOF

# build theme 'ananke' container and push to hub.docker.com
docker build --no-cache -t ${DOCKER_HUB_USERNAME}/${SITE}:${K8S_BLOG_TAG} --rm .
docker push ${DOCKER_HUB_USERNAME}/${SITE}:${K8S_BLOG_TAG}
#docker rmi $(docker images --filter=reference="${DOCKER_HUB_USERNAME}/${SITE}" -q)

read -p "Now, set theme (t2) for our web-application. Press enter to continue"

# Now we are going to buid another image based on a different theme.
# push theme 'bilberry' to github
export K8S_BLOG_TAG="t2"
pushd $SITE
/bin/cp -avR themes/bilberry-hugo-theme/exampleSite/* .
popd
git -C ${SITE}/ commit -a -m "Set theme to ${K8S_BLOG_TAG}"
git -C ${SITE}/ push -u origin master

# build theme 'bilberry' container and push to hub.docker.com
docker build --no-cache -t ${DOCKER_HUB_USERNAME}/${SITE}:${K8S_BLOG_TAG} --rm .
docker push ${DOCKER_HUB_USERNAME}/${SITE}:${K8S_BLOG_TAG}
#docker rmi $(docker images --filter=reference="${DOCKER_HUB_USERNAME}/${SITE}" -q)

echo "done. Both theme images are pushed to dockerhub"
