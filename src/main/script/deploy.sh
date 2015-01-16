#!/bin/bash
API=https://api.bintray.com
PACKAGE_DESCRIPTOR=bintray-package.json
BINTRAY_USERNAME=$1
BINTRAY_PASSWORD=$2
BINTRAY_REPO=$3
PACKAGE=$4
GROUP=$(echo "$5" | sed -r 's/\./\//g')
CURL="curl -u${BINTRAY_USERNAME}:${BINTRAY_PASSWORD} -H Content-Type:application/json -H Accept:application/json"
RELEASES_COUNT=-10
RELEASES_START=3
RELEASES_END=4

download () {
    VERSION=$1
    wget -t 30 -w 5 --waitretry 20 --random-wait -O - https://github.com/jgraph/jgraphx/archive/v${VERSION}.tar.gz | tar -C ./target/${f} --strip-components=1 -zx
    mv target/${VERSION}/lib/jgraphx.jar target/${VERSION}/lib/jgraphx-${VERSION}.jar
    return
}

pom () {
    VERSION=$1
    cp src/main/resources/pom.xml target/${VERSION}/lib/jgraphx-$VERSION.pom
    sed -i "s/@@VERSION@@/$VERSION/g" target/${VERSION}/lib/jgraphx-$VERSION.pom
    return
}

sources () {
    VERSION=$1
    jar cvf target/${VERSION}/lib/jgraphx-${VERSION}-sources.jar -C target/${VERSION}/src/ .
    return
}

javadoc () {
    VERSION=$1
    jar cvf target/${VERSION}/lib/jgraphx-${VERSION}-javadoc.jar -C target/${VERSION}/docs/api/ .
    return
}

sign () {
    VERSION=$1
    POM="target/$VERSION/lib/jgraphx-$VERSION.pom"
    JAR="target/$VERSION/lib/jgraphx-$VERSION.jar"
    JAVADOC="target/$VERSION/lib/jgraphx-$VERSION-javadoc.jar"
    SOURCES="target/$VERSION/lib/jgraphx-$VERSION-sources.jar"
    gpg2 -ab $POM
    gpg2 -ab $JAR
    gpg2 -ab $SOURCES
    gpg2 -ab $JAVADOC
    echo "Signed all files of $VERSION"
    return
}

function upload() {
    NAME=$1
    VERSION=$2
    FILE="target/$VERSION/lib/$NAME"
    uploaded=$(${CURL} --write-out %{http_code} --silent --output /dev/null -T ${FILE} -H X-Bintray-Package:${PACKAGE} -H X-Bintray-Version:${VERSION} ${API}/content/${BINTRAY_USERNAME}/${BINTRAY_REPO}/${GROUP}/${PACKAGE}/${VERSION}/${NAME})
    echo "File ${FILE} uploaded? y:1/N:0 ${uploaded}"
    return ${uploaded}
}

deploy () {
    VERSION=$1
    POM="jgraphx-$VERSION.pom"
    JAR="jgraphx-$VERSION.jar"
    SOURCES="jgraphx-$VERSION-sources.jar"
    JAVADOC="jgraphx-$VERSION-javadoc.jar"
    upload $POM $VERSION
    upload ${POM}.asc $VERSION
    echo "$POM deployd."
    upload $JAR $VERSION
    upload ${JAR}.asc $VERSION
    echo "$JAR deployd."
    upload $SOURCES $VERSION
    upload ${SOURCES}.asc $VERSION
    echo "$SOURCES deployed."
    upload $JAVADOC $VERSION
    upload ${JAVADOC}.asc $VERSION
    echo "$JAVADOC deployed."
    return
}

main () {
    JGRAPHX_FILES=$(wget -O- https://github.com/jgraph/jgraphx/releases | egrep -o '/jgraph/jgraphx/archive/v[0-9\-\.]+.tar.gz' | sed -rn "s/\/jgraph\/jgraphx\/archive\/v([0-9\-\.]+).tar.gz/\\1/p" | sort -V | tail $RELEASES_COUNT)
    #echo $JGRAPHX_FILES
    JGRAPHX_FILES=(${JGRAPHX_FILES// / })
    #JGRAPHX_FILES=("${JGRAPHX_FILES[@]:$RELEASES_START:$RELEASES_END}")
    #echo $JGRAPHX_FILES

    mkdir target

    for f in ${JGRAPHX_FILES[@]}; do
        mkdir -p target/${f}

        download ${f}
        pom ${f}
        sources ${f}
        javadoc ${f}
        sign ${f}
        deploy ${f}
    done
}

main "$@"