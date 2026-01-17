# Script para actualizar el usuario en gastos existentes
# Ejecutar con: rails runner update_expenses_user.rb

puts "Actualizando gastos sin usuario asignado..."

updated = 0
Expense.where(user_id: nil).each do |expense|
  if expense.project && expense.project.user
    expense.update_attribute(:user_id, expense.project.user.id)
    updated += 1
  end
end

puts "✅ #{updated} gastos actualizados"
