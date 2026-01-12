-- | Example program using Example
--
-- Run with: example -r app/Main.hs

module Main where

import Example

main :: IO ()
main = do
    -- Initialize
    ok <- Example.init
    if ok
        then do
            -- Get version
            v <- Example.version
            putStrLn $ "Example version: " ++ v

            -- Use the API
            result <- Example.process 21
            putStrLn $ "process 21 = " ++ show result

            combined <- Example.combine 10 32
            putStrLn $ "combine 10 32 = " ++ show combined

            Example.action 42

            -- Cleanup
            Example.cleanup
        else
            putStrLn "Failed to initialize Example"
