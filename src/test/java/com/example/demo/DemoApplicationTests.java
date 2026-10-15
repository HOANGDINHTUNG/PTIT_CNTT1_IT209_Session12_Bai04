package com.example.demo;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
class DemoApplicationTests {

    @Test
    void contextLoads() {
        assertTrue(true, "Application context loaded successfully");
    }

    @Test
    void simpleUnitTest() {
        int a = 10;
        int b = 20;
        assertEquals(30, a + b, "Basic calculation unit test");
    }

}
