package org.owasp.wrongsecrets.challenges.docker;


import lombok.extern.slf4j.Slf4j;
import org.owasp.wrongsecrets.RuntimeEnvironment;
import org.owasp.wrongsecrets.ScoreCard;
import org.owasp.wrongsecrets.challenges.Challenge;
import org.owasp.wrongsecrets.challenges.Spoiler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;

@Slf4j
@Component
public class Challenge12 extends Challenge {

    private String dockerMountPath;

    public Challenge12(ScoreCard scoreCard, @Value("${challengedockermtpath}") String dockerMountPath) {
        super(scoreCard);
        this.dockerMountPath = dockerMountPath;
    }

    @Override
    public Spoiler spoiler() {
        return new Spoiler(getActualData());
    }

    @Override
    public boolean answerCorrect(String answer) {
        log.info("challenge 12, actualdata: {}, answer: {}", getActualData(), answer);
        return getActualData().equals(answer);
    }

    @Override
    public List<RuntimeEnvironment.Environment> supportedRuntimeEnvironments() {
        return List.of(RuntimeEnvironment.Environment.DOCKER);
    }

    private String getActualData() {
        try {
            return Files.readString(Paths.get(dockerMountPath, "yourkey.txt"));
        } catch (Exception e) {
            log.warn("Exception during file reading, defaulting to default without cloud environment", e);
            return "if_you_see_this_please_use_docker_instead";
        }
    }
}
