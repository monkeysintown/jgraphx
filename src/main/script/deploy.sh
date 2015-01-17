#!/bin/bash
BINTRAY=https://bintray.com
API=https://api.bintray.com
PACKAGE_DESCRIPTOR=bintray-package.json
BINTRAY_USERNAME=$1
BINTRAY_PASSWORD=$2
BINTRAY_REPO=$3
PACKAGE=$4
GROUP=$(echo "$5" | sed -r 's/\./\//g')
CURL="curl --silent --output /dev/null -u${BINTRAY_USERNAME}:${BINTRAY_PASSWORD} -H Content-Type:application/json -H Accept:application/json"
RELEASES_COUNT=-1
RELEASES_START=3
RELEASES_END=4

log () {
    echo -e "\e[94mINFO  \e[0m$1"
}

log_warn () {
    echo -e "\e[33mWARN  \e[0m$1"
}

log_error () {
    echo -e "\e[31mERROR \e[0m$1"
}

checkfile () {
    VERSION=$1
    NAME=$2

    RESPONSE=$(${CURL} --write-out %{http_code} ${BINTRAY}/artifact/download/cheetah/monkeysintown/com/github/monkeysintown/jgraphx/${VERSION}/${NAME})

    if [ $RESPONSE == "200" ] || [ $RESPONSE == "201" ] || [ $RESPONSE == "302" ]
    then
        echo "1"
    elif [ $RESPONSE == "401" ]
    then
        echo "-1"
    else
        echo "0"
    fi
}

download () {
    VERSION=$1

    if [ -f target/${VERSION}/lib/jgraphx-$VERSION.jar ];
    then
        log "Version $VERSION already downloaded from Github."
    else
        wget --quiet -t 30 -w 5 --waitretry 20 --random-wait -O - https://github.com/jgraph/jgraphx/archive/v${VERSION}.tar.gz | tar -C ./target/${VERSION} --strip-components=1 -zx
        mv target/${VERSION}/lib/jgraphx.jar target/${VERSION}/lib/jgraphx-${VERSION}.jar
    fi

    return
}

pom () {
    VERSION=$1

    if [ -f target/${VERSION}/lib/jgraphx-$VERSION.pom ];
    then
        log "jgraphx-$VERSION.pom exists."
    else
        cp src/main/resources/pom.xml target/${VERSION}/lib/jgraphx-$VERSION.pom
        sed -i "s/@@VERSION@@/$VERSION/g" target/${VERSION}/lib/jgraphx-$VERSION.pom
    fi

    return
}

sources () {
    VERSION=$1

    if [ -f target/${VERSION}/lib/jgraphx-${VERSION}-sources.jar ];
    then
        log "jgraphx-${VERSION}-sources.jar exists."
    else
        jar cf target/${VERSION}/lib/jgraphx-${VERSION}-sources.jar -C target/${VERSION}/src/ .
    fi

    return
}

javadoc () {
    VERSION=$1

    if [ -f target/${VERSION}/lib/jgraphx-${VERSION}-javadoc.jar ];
    then
        log "jgraphx-${VERSION}-javadoc.jar exists."
    else
        jar cf target/${VERSION}/lib/jgraphx-${VERSION}-javadoc.jar -C target/${VERSION}/docs/api/ .
    fi

    return
}

sign () {
    VERSION=$1
    POM="target/$VERSION/lib/jgraphx-$VERSION.pom"
    JAR="target/$VERSION/lib/jgraphx-$VERSION.jar"
    JAVADOC="target/$VERSION/lib/jgraphx-$VERSION-javadoc.jar"
    SOURCES="target/$VERSION/lib/jgraphx-$VERSION-sources.jar"

    if [ -f "$POM.asc" ];
    then
        log "$POM already signed."
    else
        gpg2 -ab $POM
        log "Signed $POM."
    fi
    if [ -f "$JAR.asc" ];
    then
        log "$JAR already signed."
    else
        gpg2 -ab $JAR
        log "Signed $JAR."
    fi
    if [ -f "$SOURCES.asc" ];
    then
        log "$SOURCES already signed."
    else
        gpg2 -ab $SOURCES
        log "Signed $SOURCES."
    fi
    if [ -f "$JAVADOC.asc" ];
    then
        log "$JAVADOC already signed."
    else
        gpg2 -ab $JAVADOC
        log "Signed $JAVADOC."
    fi

    return
}

upload() {
    VERSION=$1
    NAME=$2
    FILE="target/$VERSION/lib/$NAME"
    uploaded=$(${CURL} --write-out %{http_code} -T ${FILE} -H X-Bintray-Package:${PACKAGE} -H X-Bintray-Version:${VERSION} ${API}/content/${BINTRAY_USERNAME}/${BINTRAY_REPO}/${GROUP}/${PACKAGE}/${VERSION}/${NAME})
    log "File ${FILE} uploaded."
    return ${uploaded}
}

deploy () {
    VERSION=$1
    POM="jgraphx-$VERSION.pom"
    JAR="jgraphx-$VERSION.jar"
    SOURCES="jgraphx-$VERSION-sources.jar"
    JAVADOC="jgraphx-$VERSION-javadoc.jar"

    if [ "$(checkfile $VERSION $POM)" == 1 ]; then
        log "$POM already deployd."
    else
        upload $VERSION $POM
        upload $VERSION ${POM}.asc $VERSION
        log "$POM deployd."
    fi
    if [ "$(checkfile $VERSION $JAR)" == 1 ]; then
        log "$JAR already deployd."
    else
        upload $VERSION $JAR $VERSION
        upload $VERSION ${JAR}.asc $VERSION
        log "$JAR deployd."
    fi
    if [ "$(checkfile $VERSION $SOURCES)" == 1 ]; then
        log "$SOURCES already deployed."
    else
        upload $VERSION $SOURCES $VERSION
        upload $VERSION ${SOURCES}.asc $VERSION
        log "$SOURCES deployed."
    fi
    if [ "$(checkfile $VERSION $JAVADOC)" == 1 ]; then
        log "$JAVADOC already deployed."
    else
        upload $VERSION $JAVADOC $VERSION
        upload $VERSION ${JAVADOC}.asc $VERSION
        log "$JAVADOC deployed."
    fi

    return
}

main () {
    JGRAPHX_VERSIONS=$(wget -O- --quiet https://github.com/jgraph/jgraphx/releases | egrep -o '/jgraph/jgraphx/archive/v[0-9\-\.]+.tar.gz' | sed -rn "s/\/jgraph\/jgraphx\/archive\/v([0-9\-\.]+).tar.gz/\\1/p" | sort -V | tail $RELEASES_COUNT)
    #echo $JGRAPHX_VERSIONS
    JGRAPHX_VERSIONS=(${JGRAPHX_VERSIONS// / })
    #JGRAPHX_VERSIONS=("${JGRAPHX_VERSIONS[@]:$RELEASES_START:$RELEASES_END}")

    for v in ${JGRAPHX_VERSIONS[@]}; do

        RES=$(checkfile ${v} jgraphx-${v}.pom)

        if [ "$RES" == 1 ]
        then
            log_warn "Version ${v} already uploaded."
        elif [ "$RES" == -1 ]
        then
            log_error "You are not authorized!"
            exit 1
        else
            if [ ! -d target/${v} ]
            then
                mkdir -p target/${v}
                log "directory target/${v} created."
            fi

            download ${v}
            pom ${v}
            sources ${v}
            javadoc ${v}
            sign ${v}
            deploy ${v}
        fi
    done
}

main "$@"