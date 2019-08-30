if [ "$#" -ne 1 ]; then
	echo "Usage: add-version url"
	exit
fi

URL=$1
if [[ $URL =~ ^([^\?]+)(\?.+)?$ ]]; then
	URL=${BASH_REMATCH[1]}
fi

if [[ $URL =~ builtin_shaders-(.+)\.zip$ ]]; then
	VERSION=${BASH_REMATCH[1]}
else
	echo "Invalid URL"
	exit
fi

ZIP_FILENAME="builtin_shaders-${VERSION}.zip"

if [[ $VERSION =~ ^([0-9]+\.[0-9]+)\. ]]; then
	MAJOR_BRANCH=${BASH_REMATCH[1]}
fi

LOCAL_BRANCH_COUNT=`git branch --list | grep "$MAJOR_BRANCH" | wc -l`
REMOTE_BRANCH_COUNT=`git branch -r | grep "origin/${MAJOR_BRANCH}" | wc -l`

git fetch --all

git checkout master
git pull

if [ $LOCAL_BRANCH_COUNT -eq 1 ]; then
	git checkout $MAJOR_BRANCH
elif [ $REMOTE_BRANCH_COUNT -eq 1 ]; then
	git checkout -b $MAJOR_BRANCH "origin/${MAJOR_BRANCH}" 
else
	git checkout -b $MAJOR_BRANCH
fi

git pull

VERSIONS_FILENAME="VERSIONS.md"
echo "* Version ${VERSION}: ${URL}\n$(cat $VERSIONS_FILENAME)" > $VERSIONS_FILENAME
SORTED_VERSIONS="$(sort -V -r $VERSIONS_FILENAME)"
echo "${SORTED_VERSIONS}" > $VERSIONS_FILENAME

rm -Rf Shaders

curl $URL -o $ZIP_FILENAME
unzip $ZIP_FILENAME -d Shaders
rm $ZIP_FILENAME

COMMIT_MESSAGE="Version ${VERSION}"
TAG_MESSAGE="${COMMIT_MESSAGE}"

git add --all
git commit -m "${COMMIT_MESSAGE}"
git push --set-upstream origin "${MAJOR_BRANCH}"
git tag -a "v${VERSION}" -m "${TAG_MESSAGE}"
git push --tags

git checkout master

VERSIONS_FILENAME="VERSIONS.md"
echo "* Version ${VERSION}: ${URL}\n$(cat $VERSIONS_FILENAME)" > $VERSIONS_FILENAME
SORTED_VERSIONS="$(sort -V -r $VERSIONS_FILENAME)"
echo "${SORTED_VERSIONS}" > $VERSIONS_FILENAME

git add --all
git commit -m "Updated ${VERSIONS_FILENAME}"
git push
