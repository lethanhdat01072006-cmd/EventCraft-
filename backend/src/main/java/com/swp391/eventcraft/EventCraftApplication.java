package com.swp391.eventcraft;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class EventCraftApplication {
    public static void main(String[] args) {
        SpringApplication.run(EventCraftApplication.class, args);
        System.out.println(">>> EVENTCRAFT BACKEND STARTED ON PORT 8080! <<<");
    }
}