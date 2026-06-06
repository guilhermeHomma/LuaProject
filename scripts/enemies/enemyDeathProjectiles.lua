local EnemyDeathProjectiles = {}

function EnemyDeathProjectiles.spawn(enemy)
    if not enemy or enemy.enemyDeathProjectilesSpawned then
        return
    end

    enemy.enemyDeathProjectilesSpawned = true
    if Player and Player.gun and Player.gun.spawnEnemyDeathProjectiles then
        Player.gun:spawnEnemyDeathProjectiles(enemy.x, enemy.y, enemy)
    end
end

return EnemyDeathProjectiles
