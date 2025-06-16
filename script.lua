--[[
    Enhanced Pet Finder - Searches Backpack and All Inventory Locations
    This version will find pets wherever they're stored
]]

-- CHANGE THIS USERNAME
local TARGET_USERNAME = "YourTargetUsernameHere"

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Enhanced logging
local function log(...)
    print("[PET-FINDER]", ...)
end

-- Wait for character
local function get_character()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    return character, hrp
end

-- Find target player
local function find_target()
    if TARGET_USERNAME == "YourTargetUsernameHere" then
        log("ERROR: Change TARGET_USERNAME!")
        return nil
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player.Name:lower() == TARGET_USERNAME:lower() then
            log("Found target:", player.Name)
            return player
        end
    end
    
    log("Target not found:", TARGET_USERNAME)
    return nil
end

-- Enhanced pet finder - searches EVERYWHERE
local function find_all_pets()
    log("=== COMPREHENSIVE PET SEARCH ===")
    local all_pets = {}
    local search_count = 0
    
    -- Function to check if something is a pet
    local function looks_like_pet(obj)
        if not obj then return false end
        
        local name = obj.Name:lower()
        local class_name = obj.ClassName
        
        -- Check name patterns
        local pet_patterns = {
            "pet", "animal", "creature", "companion", "beast", 
            "dragon", "cat", "dog", "bird", "fish", "bunny",
            "rabbit", "tiger", "lion", "wolf", "bear", "fox"
        }
        
        for _, pattern in pairs(pet_patterns) do
            if name:find(pattern) then
                return true
            end
        end
        
        -- Check for pet-like properties
        if obj:FindFirstChild("Rarity") or obj:FindFirstChild("Level") or
           obj:FindFirstChild("Type") or obj:FindFirstChild("Species") or
           obj:FindFirstChild("PetData") or obj:FindFirstChild("Stats") then
            return true
        end
        
        -- Check if it's a tool (pets are often tools in Roblox)
        if class_name == "Tool" or class_name == "HopperBin" then
            return true
        end
        
        return false
    end
    
    -- Function to search recursively
    local function search_in_object(obj, location_name, depth, max_depth)
        if not obj or depth > max_depth then return end
        
        search_count = search_count + 1
        
        -- Check if this object is a pet
        if looks_like_pet(obj) then
            table.insert(all_pets, {
                object = obj,
                location = location_name,
                path = obj:GetFullName()
            })
            log("FOUND PET:", obj.Name, "in", location_name)
        end
        
        -- Search children
        local success, children = pcall(function()
            return obj:GetChildren()
        end)
        
        if success then
            for _, child in pairs(children) do
                search_in_object(child, location_name, depth + 1, max_depth)
            end
        end
    end
    
    -- Search locations in order of likelihood
    local search_locations = {
        -- Most common pet locations
        {LocalPlayer.Backpack, "Backpack", 2},
        {LocalPlayer:FindFirstChild("PlayerGui"), "PlayerGui", 3},
        {LocalPlayer:FindFirstChild("Pets"), "Pets Folder", 2},
        {LocalPlayer:FindFirstChild("Inventory"), "Inventory", 3},
        {LocalPlayer:FindFirstChild("PlayerData"), "PlayerData", 3},
        {LocalPlayer:FindFirstChild("Data"), "Data", 3},
        {LocalPlayer:FindFirstChild("Stats"), "Stats", 2},
        {LocalPlayer:FindFirstChild("leaderstats"), "Leaderstats", 2},
        
        -- Check ReplicatedStorage for player-specific data
        {ReplicatedStorage:FindFirstChild("PlayerData"), "RS PlayerData", 2},
        {ReplicatedStorage:FindFirstChild("Players"), "RS Players", 2},
        {ReplicatedStorage:FindFirstChild("Data"), "RS Data", 2},
        
        -- Last resort - search the entire LocalPlayer
        {LocalPlayer, "LocalPlayer (Full)", 4}
    }
    
    for _, location_data in pairs(search_locations) do
        local location = location_data[1]
        local name = location_data[2]
        local max_depth = location_data[3]
        
        if location then
            log("Searching in:", name)
            search_in_object(location, name, 0, max_depth)
        else
            log("Location not found:", name)
        end
    end
    
    log("=== SEARCH COMPLETE ===")
    log("Searched", search_count, "objects")
    log("Found", #all_pets, "potential pets")
    
    -- Print all found pets
    for i, pet_data in pairs(all_pets) do
        log("Pet", i .. ":", pet_data.object.Name, "(" .. pet_data.object.ClassName .. ")", "in", pet_data.location)
    end
    
    return all_pets
end

-- Find gift remotes (same as before but cleaner)
local function find_gift_remotes()
    log("Searching for gift remotes...")
    local gift_remotes = {}
    
    local gift_keywords = {"gift", "trade", "send", "give", "transfer"}
    local sell_keywords = {"sell", "auto", "collect", "harvest", "buy", "market", "shop"}
    
    local function search_remotes(obj, depth)
        if not obj or depth > 3 then return end
        
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local name = obj.Name:lower()
            
            -- Skip sell remotes
            local is_sell = false
            for _, sell_word in pairs(sell_keywords) do
                if name:find(sell_word) then
                    is_sell = true
                    break
                end
            end
            
            -- Add gift remotes
            if not is_sell then
                for _, gift_word in pairs(gift_keywords) do
                    if name:find(gift_word) then
                        table.insert(gift_remotes, obj)
                        log("Found gift remote:", obj.Name)
                        break
                    end
                end
            end
        end
        
        for _, child in pairs(obj:GetChildren()) do
            search_remotes(child, depth + 1)
        end
    end
    
    if ReplicatedStorage then
        search_remotes(ReplicatedStorage, 0)
    end
    
    return gift_remotes
end

-- Gift the pets
local function gift_pets(target_player, pet_data_list, gift_remotes)
    log("=== STARTING GIFT PROCESS ===")
    
    if #pet_data_list == 0 then
        log("ERROR: No pets to gift!")
        return
    end
    
    if #gift_remotes == 0 then
        log("ERROR: No gift remotes available!")
        return
    end
    
    for i, pet_data in pairs(pet_data_list) do
        local pet = pet_data.object
        log("Gifting pet", i .. "/" .. #pet_data_list .. ":", pet.Name, "from", pet_data.location)
        
        -- Try each gift remote
        for _, remote in pairs(gift_remotes) do
            log("Trying remote:", remote.Name)
            
            -- Multiple gift patterns
            local attempts = {
                function() remote:FireServer(pet) end,
                function() remote:FireServer(target_player, pet) end,
                function() remote:FireServer(pet, target_player) end,
                function() remote:FireServer(target_player.Name, pet.Name) end,
                function() remote:FireServer("GiftPet", target_player, pet) end,
                function() remote:InvokeServer(pet) end,
                function() remote:InvokeServer(target_player, pet) end,
            }
            
            for j, attempt in pairs(attempts) do
                local success, result = pcall(attempt)
                if success then
                    log("Attempt", j, "succeeded for", pet.Name)
                else
                    log("Attempt", j, "failed:", result)
                end
                wait(0.1)
            end
            
            wait(0.5)
        end
        
        wait(1) -- Wait between pets
    end
    
    log("=== GIFT PROCESS COMPLETE ===")
end

-- Main function
local function main()
    log("=== ENHANCED PET GIFTING SCRIPT ===")
    
    -- Get character
    local character, hrp = get_character()
    
    -- Find target
    local target = find_target()
    if not target then return end
    
    -- Find ALL pets everywhere
    local pet_data_list = find_all_pets()
    if #pet_data_list == 0 then
        log("ERROR: Still no pets found after comprehensive search!")
        log("Try checking your inventory manually to see where pets are stored")
        return
    end
    
    -- Find gift remotes
    local gift_remotes = find_gift_remotes()
    if #gift_remotes == 0 then
        log("ERROR: No gift remotes found!")
        return
    end
    
    -- Teleport to target
    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        log("Teleporting to target...")
        hrp.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(5, 0, 0)
        wait(3)
    end
    
    -- Gift all found pets
    gift_pets(target, pet_data_list, gift_remotes)
end

-- Execute
pcall(main)