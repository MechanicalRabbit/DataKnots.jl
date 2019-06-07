using DataKnots
using CSV

employee_csv = """
    name,department,position,salary
    "ANTHONY A","POLICE","POLICE OFFICER",72510
    "JEFFERY A","POLICE","SERGEANT",101442
    "NANCY A","POLICE","POLICE OFFICER",80016
    "DANIEL A","FIRE","FIRE FIGHTER-EMT",95484
    "ROBERT K","FIRE","FIRE FIGHTER-EMT",103272
    """ |> IOBuffer |> CSV.File

chicago =
    @query DataKnot(:employee => employee_csv) {
               department => begin
                   employee
                   group(name => department)
                   collect(begin
                       employee
                       collect(department=>nothing)
                   end)
               end}
