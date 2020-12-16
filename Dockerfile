FROM adoptopenjdk/openjdk15

EXPOSE 8080


COPY target/spring-boot-0.0.1-SNAPSHOT.jar spring.jar

ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","spring.jar"]
