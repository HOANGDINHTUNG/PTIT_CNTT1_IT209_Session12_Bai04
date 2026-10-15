package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class HelloController {

    @GetMapping("/")
    public Map<String, Object> index() {
        return Map.of(
                "status", "UP",
                "message", "Spring Boot Application is running on VPS via SSH Deploy",
                "timestamp", System.currentTimeMillis()
        );
    }

}
